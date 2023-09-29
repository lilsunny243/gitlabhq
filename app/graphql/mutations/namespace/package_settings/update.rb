# frozen_string_literal: true

module Mutations
  module Namespace
    module PackageSettings
      class Update < Mutations::BaseMutation
        graphql_name 'UpdateNamespacePackageSettings'

        include Mutations::ResolvesNamespace

        NUGET_DUPLICATES_FF_ERROR = '`nuget_duplicates_option` feature flag is disabled.'

        description <<~DESC
          These settings can be adjusted by the group Owner or Maintainer.
          [Issue 370471](https://gitlab.com/gitlab-org/gitlab/-/issues/370471) proposes limiting
          this to Owners only to match the permissions level in the user interface.
        DESC

        authorize :admin_package

        argument :namespace_path,
                GraphQL::Types::ID,
                required: true,
                description: 'Namespace path where the namespace package setting is located.'

        argument :maven_duplicates_allowed,
                GraphQL::Types::Boolean,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :maven_duplicates_allowed)

        argument :maven_duplicate_exception_regex,
                Types::UntrustedRegexp,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :maven_duplicate_exception_regex)

        argument :generic_duplicates_allowed,
                GraphQL::Types::Boolean,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :generic_duplicates_allowed)

        argument :generic_duplicate_exception_regex,
                Types::UntrustedRegexp,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :generic_duplicate_exception_regex)

        argument :nuget_duplicates_allowed,
                GraphQL::Types::Boolean,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :nuget_duplicates_allowed)

        argument :nuget_duplicate_exception_regex,
                Types::UntrustedRegexp,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :nuget_duplicate_exception_regex)

        argument :maven_package_requests_forwarding,
                GraphQL::Types::Boolean,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :maven_package_requests_forwarding)

        argument :npm_package_requests_forwarding,
                GraphQL::Types::Boolean,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :npm_package_requests_forwarding)

        argument :pypi_package_requests_forwarding,
                GraphQL::Types::Boolean,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :pypi_package_requests_forwarding)

        argument :lock_maven_package_requests_forwarding,
                GraphQL::Types::Boolean,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :lock_maven_package_requests_forwarding)

        argument :lock_npm_package_requests_forwarding,
                GraphQL::Types::Boolean,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :lock_npm_package_requests_forwarding)

        argument :lock_pypi_package_requests_forwarding,
                GraphQL::Types::Boolean,
                required: false,
                description: copy_field_description(Types::Namespace::PackageSettingsType, :lock_pypi_package_requests_forwarding)

        field :package_settings,
              Types::Namespace::PackageSettingsType,
              null: true,
              description: 'Namespace package setting after mutation.'

        def resolve(namespace_path:, **args)
          namespace = authorized_find!(namespace_path: namespace_path)

          if nuget_duplicate_settings_present?(args) && Feature.disabled?(:nuget_duplicates_option, namespace)
            raise_resource_not_available_error! NUGET_DUPLICATES_FF_ERROR
          end

          result = ::Namespaces::PackageSettings::UpdateService
            .new(container: namespace, current_user: current_user, params: args)
            .execute

          {
            package_settings: result.payload[:package_settings],
            errors: result.errors
          }
        end

        private

        def find_object(namespace_path:)
          resolve_namespace(full_path: namespace_path)
        end

        def nuget_duplicate_settings_present?(args)
          args.key?(:nuget_duplicates_allowed) || args.key?(:nuget_duplicate_exception_regex)
        end
      end
    end
  end
end
