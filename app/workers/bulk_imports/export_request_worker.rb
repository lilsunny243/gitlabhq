# frozen_string_literal: true

module BulkImports
  class ExportRequestWorker
    include ApplicationWorker

    idempotent!
    data_consistency :always
    feature_category :importers
    sidekiq_options dead: false, retry: 5
    worker_has_external_dependencies!

    sidekiq_retries_exhausted do |msg, exception|
      new.perform_failure(exception, msg['args'].first)
    end

    def perform(entity_id)
      @entity = BulkImports::Entity.find(entity_id)

      set_source_xid
      request_export

      BulkImports::EntityWorker.perform_async(entity_id)
    end

    def perform_failure(exception, entity_id)
      @entity = BulkImports::Entity.find(entity_id)

      log_and_fail(exception)
    end

    private

    attr_reader :entity

    def set_source_xid
      entity.update!(source_xid: entity_source_xid) if entity.source_xid.nil?
    end

    def request_export
      http_client.post(export_url)
    end

    def http_client
      @client ||= Clients::HTTP.new(
        url: entity.bulk_import.configuration.url,
        token: entity.bulk_import.configuration.access_token
      )
    end

    def failure_attributes(exception)
      {
        bulk_import_entity_id: entity.id,
        pipeline_class: 'ExportRequestWorker',
        exception_class: exception.class.to_s,
        exception_message: exception.message.truncate(255),
        correlation_id_value: Labkit::Correlation::CorrelationId.current_or_new_id
      }
    end

    def graphql_client
      @graphql_client ||= BulkImports::Clients::Graphql.new(
        url: entity.bulk_import.configuration.url,
        token: entity.bulk_import.configuration.access_token
      )
    end

    def entity_source_xid
      response = graphql_client.execute(
        graphql_client.parse(entity_query.to_s),
        { full_path: entity.source_full_path }
      ).original_hash

      ::GlobalID.parse(response.dig(*entity_query.data_path, 'id')).model_id
    rescue StandardError => e
      log_exception(e,
        {
          message: 'Failed to fetch source entity id',
          bulk_import_entity_id: entity.id,
          bulk_import_id: entity.bulk_import_id,
          bulk_import_entity_type: entity.source_type,
          source_full_path: entity.source_full_path,
          source_version: entity.bulk_import.source_version_info.to_s,
          importer: 'gitlab_migration'
        }
      )

      nil
    end

    def entity_query
      @entity_query ||= if entity.group?
                          BulkImports::Groups::Graphql::GetGroupQuery.new(context: nil)
                        else
                          BulkImports::Projects::Graphql::GetProjectQuery.new(context: nil)
                        end
    end

    def logger
      @logger ||= Gitlab::Import::Logger.build
    end

    def log_exception(exception, payload)
      Gitlab::ExceptionLogFormatter.format!(exception, payload)

      logger.error(structured_payload(payload))
    end

    def log_and_fail(exception)
      log_exception(exception,
        {
          bulk_import_entity_id: entity.id,
          bulk_import_id: entity.bulk_import_id,
          bulk_import_entity_type: entity.source_type,
          source_full_path: entity.source_full_path,
          message: "Request to export #{entity.source_type} failed",
          source_version: entity.bulk_import.source_version_info.to_s,
          importer: 'gitlab_migration'
        }
      )

      BulkImports::Failure.create(failure_attributes(exception))

      entity.fail_op!
    end

    def export_url
      entity.export_relations_url_path(batched: Feature.enabled?(:bulk_imports_batched_import_export))
    end
  end
end
