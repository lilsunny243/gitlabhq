# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnvironmentsHelper, feature_category: :environment_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :repository) }
  let_it_be(:environment) { create(:environment, project: project) }

  describe '#metrics_data', feature_category: :metrics do
    before do
      stub_feature_flags(remove_monitor_metrics: false)

      # This is so that this spec also passes in EE.
      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:can?).and_return(true)
    end

    let(:metrics_data) { helper.metrics_data(project, environment) }

    it 'returns data' do
      expect(metrics_data).to include(
        'settings_path' => edit_project_settings_integration_path(project, 'prometheus'),
        'clusters_path' => project_clusters_path(project),
        'current_environment_name' => environment.name,
        'documentation_path' => help_page_path('administration/monitoring/prometheus/index.md'),
        'add_dashboard_documentation_path' => help_page_path('operations/metrics/dashboards/index.md', anchor: 'add-a-new-dashboard-to-your-project'),
        'empty_getting_started_svg_path' => match_asset_path('/assets/illustrations/monitoring/getting_started.svg'),
        'empty_loading_svg_path' => match_asset_path('/assets/illustrations/monitoring/loading.svg'),
        'empty_no_data_svg_path' => match_asset_path('/assets/illustrations/monitoring/no_data.svg'),
        'empty_unable_to_connect_svg_path' => match_asset_path('/assets/illustrations/monitoring/unable_to_connect.svg'),
        'deployments_endpoint' => project_environment_deployments_path(project, environment, format: :json),
        'default_branch' => 'master',
        'project_path' => project_path(project),
        'tags_path' => project_tags_path(project),
        'has_metrics' => environment.has_metrics?.to_s,
        'environment_state' => environment.state,
        'custom_metrics_path' => project_prometheus_metrics_path(project),
        'validate_query_path' => validate_query_project_prometheus_metrics_path(project),
        'custom_metrics_available' => 'true',
        'operations_settings_path' => project_settings_operations_path(project),
        'can_access_operations_settings' => 'true'
      )
    end

    context 'without admin_operations permission' do
      before do
        allow(helper).to receive(:can?)
          .with(user, :admin_operations, project)
          .and_return(false)
      end

      specify do
        expect(metrics_data).to include(
          'can_access_operations_settings' => 'false'
        )
      end
    end

    context 'when the environment is not available' do
      before do
        environment.stop
      end

      subject { metrics_data }

      it { is_expected.to include('environment_state' => 'stopped') }
    end

    context 'when metrics dashboard feature is unavailable' do
      before do
        stub_feature_flags(remove_monitor_metrics: true)
      end

      it 'does not return data' do
        expect(metrics_data).to be_empty
      end
    end
  end

  describe '#custom_metrics_available?', feature_category: :metrics do
    subject { helper.custom_metrics_available?(project) }

    before do
      project.add_maintainer(user)

      allow(helper).to receive(:current_user).and_return(user)

      allow(helper).to receive(:can?)
        .with(user, :admin_project, project)
        .and_return(true)
    end

    it 'returns true' do
      expect(subject).to eq(true)
    end
  end

  describe '#environment_logs_data' do
    it 'returns logs data' do
      expected_data = {
        "environment_name": environment.name,
        "environments_path": api_v4_projects_environments_path(id: project.id),
        "environment_id": environment.id,
        "clusters_path": project_clusters_path(project, format: :json)
      }

      expect(helper.environment_logs_data(project, environment)).to eq(expected_data)
    end
  end
end
