---
stage: Data Stores
group: Database
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# ClickHouse within GitLab

This document gives a high-level overview of how to develop features using ClickHouse in the GitLab Rails application.

NOTE:
Most of the tooling and APIs are considered unstable.

## GDK setup

For instructions on how to set up a ClickHouse server locally, see the [ClickHouse installation documentation](https://clickhouse.com/docs/en/install).

### Configure your Rails application

1. Copy the example file and configure the credentials:

   ```shell
   cp config/click_house.yml.example
   config/click_house.yml
   ```

1. Create the database using the `clickhouse-client` CLI tool:

   ```shell
   clickhouse-client --password
   ```

   ```sql
   create database gitlab_clickhouse_development;
   ```

### Validate your setup

Run the Rails console and invoke a simple query:

```ruby
ClickHouse::Client.select('SELECT 1', :main)
# => [{"1"=>1}]
```

## Database schema and migrations

For the ClickHouse database there are no established schema migration procedures yet. We have very basic tooling to build up the database schema in the test environment from scratch using timestamp-prefixed SQL files.

You can create a table by placing a new SQL file in the `db/click_house/main` folder:

```sql
// 20230811124511_create_issues.sql
CREATE TABLE issues
(
  id UInt64 DEFAULT 0,
  title String DEFAULT ''
)
ENGINE = MergeTree
PRIMARY KEY (id)
```

When you're working locally in your development environment, you can create or re-create your table schema by executing the respective `CREATE TABLE` statement. Alternatively, you can use the following snippet in the Rails console:

```ruby
require_relative 'spec/support/database/click_house/hooks.rb'

# Drops and re-creates all tables
ClickHouseTestRunner.new.ensure_schema
```

## Writing database queries

For the ClickHouse database we don't use ORM (Object Relational Mapping). The main reason is that the GitLab application has many customizations for the `ActiveRecord` PostgresSQL adapter and the application generally assumes that all databases are using `PostgreSQL`. Since ClickHouse-related features are still in a very early stage of development, we decided to implement a simple HTTP client to avoid hard to discover bugs and long debugging time when dealing with multiple `ActiveRecord` adapters.

Additionally, ClickHouse might not be used the same way as other adapters for `ActiveRecord`. The access patterns differ from traditional transactional databases, in that ClickHouse:

- Uses nested aggregation `SELECT` queries with `GROUP BY` clauses.
- Doesn't use single `INSERT` statements. Data is inserted in batches via background jobs.
- Has different consistency characteristics, no transactions.
- Has very little database-level validations.

Database queries are written and executed with the help of the `ClickHouse::Client` gem.

A simple query from the `events` table:

```ruby
rows = ClickHouse::Client.select('SELECT * FROM events', :main)
```

When working with queries with placeholders you can use the `ClickHouse::Query` object where you need to specify the placeholder name and its data type. The actual variable replacement, quoting and escaping will be done by the ClickHouse server.

```ruby
raw_query = 'SELECT * FROM events WHERE id > {min_id:UInt64}'
placeholders = { min_id: Integer(100) }
query = ClickHouse::Client::Query.new(raw_query: raw_query, placeholders: placeholders)

rows = ClickHouse::Client.select(query, :main)
```

When using placeholders the client can provide the query with redacted placeholder values which can be ingested by our logging system. You can see the redacted version of your query by calling the `to_redacted_sql` method:

```ruby
puts query.to_redacted_sql
```

ClickHouse allows only one statement per request. This means that the common SQL injection vulnerability where the statement is closed with a `;` character and then another query is "injected" cannot be exploited:

```ruby
ClickHouse::Client.select('SELECT 1; SELECT 2', :main)

# ClickHouse::Client::DatabaseError: Code: 62. DB::Exception: Syntax error (Multi-statements are not allowed): failed at position 9 (end of query): ; SELECT 2. . (SYNTAX_ERROR) (version 23.4.2.11 (official build))
```

### Subqueries

You can compose complex queries with the `ClickHouse::Client::Query` class by specifying the query placeholder with the special `Subquery` type. The library will make sure to correctly merge the queries and the placeholders:

```ruby
subquery = ClickHouse::Client::Query.new(raw_query: 'SELECT id FROM events WHERE id = {id:UInt64}', placeholders: { id: Integer(10) })

raw_query = 'SELECT * FROM events WHERE id > {id:UInt64} AND id IN ({q:Subquery})'
placeholders = { id: Integer(10), q: subquery }

query = ClickHouse::Client::Query.new(raw_query: raw_query, placeholders: placeholders)
rows = ClickHouse::Client.select(query, :main)

# ClickHouse will replace the placeholders
puts query.to_sql # SELECT * FROM events WHERE id > {id:UInt64} AND id IN (SELECT id FROM events WHERE id = {id:UInt64})

puts query.to_redacted_sql # SELECT * FROM events WHERE id > $1 AND id IN (SELECT id FROM events WHERE id = $2)

puts query.placeholders # { id: 10 }
```

In case there are placeholders with the same name but different values the query will raise an error.

### Writing query conditions

When working with complex forms where multiple filter conditions are present, building queries by concatenating query fragments as string can get out of hands very quickly. For queries with several conditions you may use the `ClickHouse::QueryBuilder` class. The class uses the `Arel` gem to generate queries and provides a similar query interface like `ActiveRecord`.

```ruby
builder = ClickHouse::QueryBuilder.new('events')

query = builder
  .where(builder.table[:created_at].lteq(Date.today))
  .where(id: [1,2,3])

rows = ClickHouse::Client.select(query, :main)
```

## Inserting data

The ClickHouse client supports inserting data through the standard query interface:

```ruby
raw_query = 'INSERT INTO events (id, target_type) VALUES ({id:UInt64}, {target_type:String})'
placeholders = { id: 1, target_type: 'Issue' }

query = ClickHouse::Client::Query.new(raw_query: raw_query, placeholders: placeholders)
rows = ClickHouse::Client.execute(query, :main)
```

Inserting data this way is acceptable if:

- The table contains settings or configuration data where we need to add one row.
- For testing, test data has to be prepared in the database.

When inserting data, we should always try to use batch processing where multiple rows are inserted at once. Building large `INSERT` queries in memory is discouraged because of the increased memory usage. Additionally, values specified within such queries cannot be redacted automatically by the client.

To compress data and reduce memory usage, insert CSV data. You can do this with the internal [`CsvBuilder`](https://gitlab.com/gitlab-org/gitlab/-/tree/master/gems/csv_builder) gem:

```ruby
iterator = Event.find_each

# insert from events table using only the id and the target_type columns
column_mapping = {
  id: :id,
  target_type: :target_type
}

CsvBuilder::Gzip.new(iterator, column_mapping).render do |tempfile|
  query = 'INSERT INTO events (id, target_type) FORMAT CSV'
  ClickHouse::Client.insert_csv(query, File.open(tempfile.path), :main)
end
```

NOTE:
It's important to test and verify efficient batching of database records from PostgreSQL. Consider using the techniques described in the [Iterating tables in batches](../iterating_tables_in_batches.md).

## Testing

ClickHouse is enabled on CI/CD but to avoid significantly affecting the pipeline runtime we've decided to run the ClickHouse server for test cases tagged with `:click_house` only.

The `:click_house` tag ensures that the database schema is properly set up before every test case.

```ruby
RSpec.describe MyClickHouseFeature, :click_house do
  it 'returns rows' do
    rows = ClickHouse::Client.select('SELECT 1', :main)
    expect(rows.size).to eq(1)
  end
end
```

## Multiple databases

By design, the `ClickHouse::Client` library supports configuring multiple databases. Because we're still at a very early stage of development, we only have one database called `main`.

Multi database configuration example:

```yaml
development:
  main:
    database: gitlab_clickhouse_main_development
    url: 'http://localhost:8123'
    username: clickhouse
    password: clickhouse

  user_analytics: # made up database
    database: gitlab_clickhouse_user_analytics_development
    url: 'http://localhost:8123'
    username: clickhouse
    password: clickhouse
```

## Observability

All queries executed via the `ClickHouse::Client` library expose the query with performance metrics (timings, read bytes) via `ActiveSupport::Notifications`.

```ruby
ActiveSupport::Notifications.subscribe('sql.click_house') do |_, _, _, _, data|
  puts data.inspect
end
```

Additionally, to view the executed ClickHouse queries in web interactions, on the performance bar, next to the `ch` label select the count.
