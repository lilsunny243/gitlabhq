# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::PipelineHelper do
  include Ci::BuildsHelper

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:raw_pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id) }
  let_it_be(:pipeline) { Ci::PipelinePresenter.new(raw_pipeline, current_user: user) }

  before do
    project.add_developer(user)
  end

  describe '#js_pipeline_tabs_data' do
    subject(:pipeline_tabs_data) { helper.js_pipeline_tabs_data(project, pipeline, user) }

    it 'returns pipeline tabs data' do
      expect(pipeline_tabs_data).to include({
        failed_jobs_count: pipeline.failed_builds.count,
        project_path: project.full_path,
        graphql_resource_etag: graphql_etag_pipeline_path(pipeline),
        metrics_path: namespace_project_ci_prometheus_metrics_histograms_path(namespace_id: project.namespace, project_id: project, format: :json),
        pipeline_iid: pipeline.iid,
        pipeline_path: pipeline_path(pipeline),
        pipeline_project_path: project.full_path,
        total_job_count: pipeline.total_size,
        summary_endpoint: summary_project_pipeline_tests_path(project, pipeline, format: :json),
        suite_endpoint: project_pipeline_test_path(project, pipeline, suite_name: 'suite', format: :json),
        blob_path: project_blob_path(project, pipeline.sha),
        has_test_report: pipeline.complete_and_has_reports?(Ci::JobArtifact.of_report_type(:test)),
        empty_dag_svg_path: match_asset_path('illustrations/empty-state/empty-dag-md.svg'),
        empty_state_image_path: match_asset_path('illustrations/empty-todos-md.svg'),
        artifacts_expired_image_path: match_asset_path('illustrations/pipeline.svg'),
        tests_count: pipeline.test_report_summary.total[:count]
      })
    end
  end

  describe '#js_pipeline_details_header_data' do
    subject(:pipeline_details_header_data) { helper.js_pipeline_details_header_data(project, pipeline) }

    it 'returns pipeline details header data' do
      expect(pipeline_details_header_data).to include({
        full_path: project.full_path,
        graphql_resource_etag: graphql_etag_pipeline_path(pipeline),
        pipeline_iid: pipeline.iid,
        pipelines_path: project_pipelines_path(project),
        name: pipeline.name,
        total_jobs: pipeline.total_size,
        yaml_errors: pipeline.yaml_errors,
        failure_reason: pipeline.failure_reason,
        triggered_by_path: '',
        schedule: pipeline.schedule?.to_s,
        child: pipeline.child?.to_s,
        latest: pipeline.latest?.to_s,
        merge_train_pipeline: pipeline.merge_train_pipeline?.to_s,
        invalid: pipeline.has_yaml_errors?.to_s,
        failed: pipeline.failure_reason?.to_s,
        auto_devops: pipeline.auto_devops_source?.to_s,
        detached: pipeline.detached_merge_request_pipeline?.to_s,
        stuck: pipeline.stuck?.to_s,
        ref_text: pipeline.ref_text
      })
    end
  end
end
