# frozen_string_literal: true
module Analytics
  module CycleAnalytics
    module StageEventModel
      extend ActiveSupport::Concern

      included do
        include FromUnion

        scope :by_stage_event_hash_id, ->(id) { where(stage_event_hash_id: id) }
        scope :by_project_id, ->(id) { where(project_id: id) }
        scope :by_group_id, ->(id) { where(group_id: id) }
        scope :end_event_timestamp_after, -> (date) { where(arel_table[:end_event_timestamp].gteq(date)) }
        scope :end_event_timestamp_before, -> (date) { where(arel_table[:end_event_timestamp].lteq(date)) }
        scope :start_event_timestamp_after, -> (date) { where(arel_table[:start_event_timestamp].gteq(date)) }
        scope :start_event_timestamp_before, -> (date) { where(arel_table[:start_event_timestamp].lteq(date)) }
        scope :authored, ->(user) { where(author_id: user) }
        scope :with_milestone_id, ->(milestone_id) { where(milestone_id: milestone_id) }
        scope :end_event_is_not_happened_yet, -> { where(end_event_timestamp: nil) }
        scope :order_by_end_event, -> (direction) do
          # ORDER BY end_event_timestamp, merge_request_id/issue_id, start_event_timestamp
          # start_event_timestamp must be included in the ORDER BY clause for the duration
          # calculation to work: SELECT end_event_timestamp - start_event_timestamp
          keyset_order(
            :end_event_timestamp => { order_expression: arel_order(arel_table[:end_event_timestamp], direction), distinct: false, nullable: direction == :asc ? :nulls_last : :nulls_first },
            issuable_id_column => { order_expression: arel_order(arel_table[issuable_id_column], direction), distinct: true },
            :start_event_timestamp => { order_expression: arel_order(arel_table[:start_event_timestamp], direction), distinct: false }
          )
        end
        scope :order_by_duration, -> (direction) do
          # ORDER BY EXTRACT('epoch', end_event_timestamp - start_event_timestamp)
          duration = Arel::Nodes::Subtraction.new(
            arel_table[:end_event_timestamp],
            arel_table[:start_event_timestamp]
          )
          duration_in_seconds = Arel::Nodes::Extract.new(duration, :epoch)

          # start_event_timestamp and end_event_timestamp do not really influence the order,
          # but are included so that they are part of the returned result, for example when
          # using Gitlab::Analytics::CycleAnalytics::Aggregated::RecordsFetcher
          keyset_order(
            :total_time => { order_expression: arel_order(duration_in_seconds, direction), distinct: false, sql_type: 'double precision' },
            issuable_id_column => { order_expression: arel_order(arel_table[issuable_id_column], direction), distinct: true },
            :end_event_timestamp => { order_expression: arel_order(arel_table[:end_event_timestamp], direction), distinct: true },
            :start_event_timestamp => { order_expression: arel_order(arel_table[:start_event_timestamp], direction), distinct: true }
          )
        end
      end

      def issuable_id
        attributes[self.class.issuable_id_column.to_s]
      end

      def total_time
        read_attribute(:total_time) || (end_event_timestamp - start_event_timestamp).to_f
      end

      class_methods do
        def upsert_data(data)
          upsert_values = data.map { |row| row.values_at(*column_list) }

          value_list = Arel::Nodes::ValuesList.new(upsert_values).to_sql

          query = <<~SQL
          INSERT INTO #{quoted_table_name}
          (
            #{insert_column_list.join(",\n")}
          )
          #{value_list}
          ON CONFLICT(stage_event_hash_id, #{issuable_id_column})
          DO UPDATE SET
            #{column_updates.join(",\n")}
          SQL

          result = connection.execute(query)
          result.cmd_tuples
        end

        def keyset_order(column_definition_options)
          built_definitions = column_definition_options.map do |attribute_name, column_options|
            ::Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(attribute_name: attribute_name, **column_options)
          end

          order(Gitlab::Pagination::Keyset::Order.build(built_definitions))
        end

        def arel_order(arel_node, direction)
          direction.to_sym == :desc ? arel_node.desc : arel_node.asc
        end

        def select_columns
          [
            issuable_model.arel_table[:id],
            issuable_model.arel_table[project_column].as('project_id'),
            issuable_model.arel_table[:milestone_id],
            issuable_model.arel_table[:author_id],
            issuable_model.arel_table[:state_id],
            Project.arel_table[:parent_id].as('group_id')
          ]
        end

        def column_list
          [
            :stage_event_hash_id,
            :issuable_id,
            :group_id,
            :project_id,
            :milestone_id,
            :author_id,
            :state_id,
            :start_event_timestamp,
            :end_event_timestamp
          ]
        end

        def insert_column_list
          [
            :stage_event_hash_id,
            connection.quote_column_name(issuable_id_column),
            :group_id,
            :project_id,
            :milestone_id,
            :author_id,
            :state_id,
            :start_event_timestamp,
            :end_event_timestamp
          ]
        end

        def column_updates
          insert_column_list.map do |column|
            "#{column} = excluded.#{column}"
          end
        end
      end
    end
  end
end
