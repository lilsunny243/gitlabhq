# frozen_string_literal: true

RSpec.shared_context 'with scan result policy blocking protected branches' do
  include RepoHelpers

  let(:policy_path) { Security::OrchestrationPolicyConfiguration::POLICY_PATH }
  let_it_be(:policy_project) { create(:project, :repository) }
  let(:default_branch) { policy_project.default_branch }

  let(:policy_yaml) do
    build(:orchestration_policy_yaml, scan_execution_policy: [], scan_result_policy: [scan_result_policy])
  end

  let(:scan_result_policy) do
    build(:scan_result_policy, branches: [branch_name], approval_settings: { block_unprotecting_branches: true })
  end

  before do
    policy_configuration.update_attribute(:security_policy_management_project, policy_project)

    create_file_in_repo(policy_project, default_branch, default_branch, policy_path, policy_yaml)

    stub_licensed_features(security_orchestration_policies: true)
  end
end
