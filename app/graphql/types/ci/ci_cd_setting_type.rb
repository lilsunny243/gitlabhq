# frozen_string_literal: true

module Types
  module Ci
    class CiCdSettingType < BaseObject
      graphql_name 'ProjectCiCdSetting'

      authorize :admin_project

      field :inbound_job_token_scope_enabled,
        GraphQL::Types::Boolean,
        null: true,
        description: 'Indicates CI/CD job tokens generated in other projects ' \
          'have restricted access to this project.',
        method: :inbound_job_token_scope_enabled?
      field :job_token_scope_enabled,
        GraphQL::Types::Boolean,
        null: true,
        description: 'Indicates CI/CD job tokens generated in this project ' \
          'have restricted access to other projects.',
        method: :job_token_scope_enabled?
      field :keep_latest_artifact,
        GraphQL::Types::Boolean,
        null: true,
        description: 'Whether to keep the latest builds artifacts.',
        method: :keep_latest_artifacts_available?
      field :merge_pipelines_enabled,
        GraphQL::Types::Boolean,
        null: true,
        description: 'Whether merge pipelines are enabled.',
        method: :merge_pipelines_enabled?
      # TODO(Issue 422295): this is EE only and should be moved to the EE file
      field :merge_trains_enabled,
        GraphQL::Types::Boolean,
        null: true,
        description: 'Whether merge trains are enabled.',
        method: :merge_trains_enabled?
      field :project,
        Types::ProjectType,
        null: true,
        description: 'Project the CI/CD settings belong to.'
    end
  end
end

Types::Ci::CiCdSettingType.prepend_mod_with('Types::Ci::CiCdSettingType')
