---
stage: none
group: Engineering Productivity
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Software design guides

## Use ubiquitous language instead of CRUD terminology

The code should use the same [ubiquitous language](https://about.gitlab.com/handbook/communication/#ubiquitous-language)
as used in the product and user documentation. Failure to use ubiquitous language correctly
can be a major cause of confusion for contributors and customers when there is constant translation
or use of multiple terms.
This also goes against our [communication strategy](https://about.gitlab.com/handbook/communication/#mecefu-terms).

In the example below, [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete)
terminology introduces ambiguity. The name says we are creating an `epic_issues`
association record, but we are adding an existing issue to an epic. The name `epic_issues`,
used from Rails convention, leaks to higher abstractions such as service objects.
The code speaks the framework jargon rather than ubiquitous language.

```ruby
# Bad
EpicIssues::CreateService
```

Using ubiquitous language makes the code clear and doesn't introduce any
cognitive load to a reader trying to translate the framework jargon.

```ruby
# Good
Epic::AddExistingIssueService
```

You can use CRUD when representing simple concepts that are not ambiguous,
like creating a project, and when matching the existing ubiquitous language.

```ruby
# OK: Matches the product language.
Projects::CreateService
```

New classes and database tables should use ubiquitous language. In this case the model name
and table name follow the Rails convention.

Existing classes that don't follow ubiquitous language should be renamed, when possible.
Some low level abstractions such as the database tables don't need to be renamed.
For example, use `self.table_name=` when the model name diverges from the table name.

We can allow exceptions only when renaming is challenging. For example, when the naming is used
for STI, exposed to the user, or if it would be a breaking change.

## Use namespaces to define bounded contexts

A healthy application is divided into macro and sub components that represent the contexts at play,
whether they are related to business domain or infrastructure code.

As GitLab code has so many features and components it's hard to see what contexts are involved.
We should expect any class to be defined inside a module/namespace that represents the contexts where it operates.

When we namespace classes inside their domain:

- Similar terminology becomes unambiguous as the domain clarifies the meaning:
  For example, `MergeRequests::Diff` and `Notes::Diff`.
- Top-level namespaces could be associated to one or more groups identified as domain experts.
- We can better identify the interactions and coupling between components.
  For example, several classes inside `MergeRequests::` domain interact more with `Ci::`
  domain and less with `ImportExport::`.

A good guideline for naming a top-level namespace (bounded context) is to use the related
[feature category](https://gitlab.com/gitlab-com/www-gitlab-com/-/blob/master/data/categories.yml).
For example, `Continuous Integration` feature category maps to `Ci::` namespace.

```ruby
# bad
class JobArtifact
end

# good
module Ci
  class JobArtifact
  end
end
```

Projects and Groups are generally container concepts because they identify tenants.
They allow features to exist at the project or group level, like repositories or runners,
but do not nest such features under `Projects::` or `Groups::`.

`Projects::` and `Groups::` namespaces should be used only for concepts that are strictly related to them:
for example `Project::CreateService` or `Groups::TransferService`.

For controllers we allow `app/controllers/projects` and `app/controllers/groups` to be exceptions.
We use this convention to indicate the scope of a given web endpoint.

Do not use the [stage or group name](https://about.gitlab.com/handbook/product/categories/#devops-stages)
because a feature category could be reassigned to a different group in the future.

```ruby
# bad
module Create
  class Commit
  end
end

# good
module Repositories
  class Commit
  end
end
```

On the other hand, a feature category may sometimes be too granular. Features tend to be
treated differently according to Product and Marketing, while they may share a lot of
domain models and behavior under the hood. In this case, having too many bounded contexts
could make them shallow and more coupled with other contexts.

Bounded contexts (or top-level namespaces) can be seen as macro-components in the overall app.
Good bounded contexts should be [deep](https://medium.com/@nakabonne/depth-of-module-f62dac3c2fdb)
so consider having nested namespaces to further break down complex parts of the domain.
For example, `Ci::Config::`.

For example, instead of having separate and granular bounded contexts like: `ContainerScanning::`,
`ContainerHostSecurity::`, `ContainerNetworkSecurity::`, we could have:

```ruby
module ContainerSecurity
  module HostSecurity
  end

  module NetworkSecurity
  end

  module Scanning
  end
end
```

If classes that are defined into a namespace have a lot in common with classes in other namespaces,
chances are that these two namespaces are part of the same bounded context.

## Distinguish domain code from generic code

The [guidelines above](#use-namespaces-to-define-bounded-contexts) refer primarily to the domain code.
For domain code we should put Ruby classes under a namespace that represents a given bounded context
(a cohesive set of features and capabilities).

The domain code is unique to GitLab product. It describes the business logic, policies and data.
This code should live in the GitLab repository. The domain code is split between `app/` and `lib/`
primarily.

In an application codebase there is also generic code that allows to perform more infrastructure level
actions. This can be loggers, instrumentation, clients for datastores like Redis, database utilities, etc.

Although vital for an application to run, generic code doesn't describe any business logic that is
unique to GitLab product. It could be rewritten or replaced by off-the-shelf solutions without impacting
the business logic.
This means that generic code should be separate from the domain code.

Today a lot of the generic code lives in `lib/` but it's mixed with domain code.
We should extract gems into `gems/` directory instead, as described in our [Gems development guidelines](gems.md).

## Taming Omniscient classes

We must consider not adding new data and behavior to [omniscient classes](https://en.wikipedia.org/wiki/God_object) (also known as god objects).
We consider `Project`, `User`, `MergeRequest`, `Ci::Pipeline` and any classes above 1000 LOC to be omniscient.

Such classes are overloaded with responsibilities. New data and behavior can most of the time be added
as a separate and dedicated class.

Guidelines:

- If you mostly need a reference to the object ID (for example `Project#id`) you could add a new model
  that uses the foreign key or a thin wrapper around the object to add special behavior.
- If you find out that by adding a method to the omniscient class you also end up adding a couple of other methods
  (private or public) it's a sign that these methods should be encapsulated in a dedicated class.
- It's temping to add a method to `Project` because that's the starting point of data and associations.
  Try to define behavior in the bounded context where it belongs, not where the data (or some of it) is.
  This helps creating facets of the omniscient object that are much more relevant in the bounded context than
  having generic and overloaded objects which bring more coupling and complexity.

### Example: Define a thin domain object around a generic model

Instead of adding multiple methods to `User` because it has an association to `abuse_trust_scores`,
try inverting the dependency.

```ruby
##
# BAD: Behavior added to User object.
class User
  def spam_score
    abuse_trust_scores.spamcheck.average(:score) || 0.0
  end

  def spammer?
    # Warning sign: we use a constant that belongs to a specific bounded context!
    spam_score > Abuse::TrustScore::SPAMCHECK_HAM_THRESHOLD
  end

  def telesign_score
    abuse_trust_scores.telesign.recent_first.first&.score || 0.0
  end

  def arkose_global_score
    abuse_trust_scores.arkose_global_score.recent_first.first&.score || 0.0
  end

  def arkose_custom_score
    abuse_trust_scores.arkose_custom_score.recent_first.first&.score || 0.0
  end
end

# Usage:
user = User.find(1)
user.spam_score
user.telesign_score
user.arkose_global_score
```

```ruby
##
# GOOD: Define a thin class that represents a user trust score
class Abuse::UserTrustScore
  def initialize(user)
    @user = user
  end

  def spam
    scores.spamcheck.average(:score) || 0.0
  end

  def spammer?
    spam > Abuse::TrustScore::SPAMCHECK_HAM_THRESHOLD
  end

  def telesign
    scores.telesign.recent_first.first&.score || 0.0
  end

  def arkose_global
    scores.arkose_global_score.recent_first.first&.score || 0.0
  end

  def arkose_custom
    scores.arkose_custom_score.recent_first.first&.score || 0.0
  end

  private

  def scores
    Abuse::TrustScore.for_user(@user)
  end
end

# Usage:
user = User.find(1)
user_score = Abuse::UserTrustScore.new(user)
user_score.spam
user_score.spammer?
user_score.telesign
user_score.arkose_global
```

See a real example [merge request](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/117853#note_1423070054).  

### Example: Use Dependency Inversion to extract a domain concept

```ruby
## 
# BAD: methods related to integrations defined in Project.
class Project
  has_many :integrations

  def find_or_initialize_integrations
    # ...
  end

  def find_or_initialize_integration(name)
    # ...
  end

  def disabled_integrations
    # ...
  end

  def ci_integrations
    # ...
  end

  # many more methods...
end
```

```ruby
##
# GOOD: All logic related to Integrations is enclosed inside the `Integrations::`
# bounded context.
module Integrations
  class ProjectIntegrations
    def initialize(project)
      @project = project
    end

    def all_integrations
      @project.integrations # can still leverage caching of AR associations
    end

    def find_or_initialize(name)
      # ...
    end

    def all_disabled
      all_integrations.disabled
    end

    def all_ci
      all_integrations.ci_integration
    end
  end
end
```

Real example of [similar refactoring](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/92985).
