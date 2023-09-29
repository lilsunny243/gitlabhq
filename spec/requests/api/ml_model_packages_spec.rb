# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::MlModelPackages, feature_category: :mlops do
  include HttpBasicAuthHelpers
  include PackagesManagerApiSpecHelpers
  include WorkhorseHelpers
  using RSpec::Parameterized::TableSyntax

  include_context 'workhorse headers'

  let_it_be(:project, reload: true) { create(:project) }
  let_it_be(:personal_access_token) { create(:personal_access_token) }
  let_it_be(:job) { create(:ci_build, :running, user: personal_access_token.user, project: project) }
  let_it_be(:deploy_token) { create(:deploy_token, read_package_registry: true, write_package_registry: true) }
  let_it_be(:project_deploy_token) { create(:project_deploy_token, deploy_token: deploy_token, project: project) }
  let_it_be(:another_project, reload: true) { create(:project) }

  let_it_be(:tokens) do
    {
      personal_access_token: personal_access_token.token,
      deploy_token: deploy_token.token,
      job_token: job.token
    }
  end

  let(:user) { personal_access_token.user }
  let(:user_role) { :developer }
  let(:member) { true }
  let(:ci_build) { create(:ci_build, :running, user: user, project: project) }
  let(:project_to_enable_ff) { project }
  let(:headers) { {} }

  shared_context 'ml model authorize permissions table' do # rubocop:disable RSpec/ContextWording
    # rubocop:disable Metrics/AbcSize
    # :visibility, :user_role, :member, :token_type, :valid_token, :expected_status
    def authorize_permissions_table
      :public  | :developer  | true  | :personal_access_token | true  | :success
      :public  | :guest      | true  | :personal_access_token | true  | :forbidden
      :public  | :developer  | true  | :personal_access_token | false | :unauthorized
      :public  | :guest      | true  | :personal_access_token | false | :unauthorized
      :public  | :developer  | false | :personal_access_token | true  | :forbidden
      :public  | :guest      | false | :personal_access_token | true  | :forbidden
      :public  | :developer  | false | :personal_access_token | false | :unauthorized
      :public  | :guest      | false | :personal_access_token | false | :unauthorized
      :public  | :anonymous  | false | :personal_access_token | true  | :unauthorized
      :private | :developer  | true  | :personal_access_token | true  | :success
      :private | :guest      | true  | :personal_access_token | true  | :forbidden
      :private | :developer  | true  | :personal_access_token | false | :unauthorized
      :private | :guest      | true  | :personal_access_token | false | :unauthorized
      :private | :developer  | false | :personal_access_token | true  | :not_found
      :private | :guest      | false | :personal_access_token | true  | :not_found
      :private | :developer  | false | :personal_access_token | false | :unauthorized
      :private | :guest      | false | :personal_access_token | false | :unauthorized
      :private | :anonymous  | false | :personal_access_token | true  | :unauthorized
      :public  | :developer  | true  | :job_token             | true  | :success
      :public  | :guest      | true  | :job_token             | true  | :forbidden
      :public  | :developer  | true  | :job_token             | false | :unauthorized
      :public  | :guest      | true  | :job_token             | false | :unauthorized
      :public  | :developer  | false | :job_token             | true  | :forbidden
      :public  | :guest      | false | :job_token             | true  | :forbidden
      :public  | :developer  | false | :job_token             | false | :unauthorized
      :public  | :guest      | false | :job_token             | false | :unauthorized
      :private | :developer  | true  | :job_token             | true  | :success
      :private | :guest      | true  | :job_token             | true  | :forbidden
      :private | :developer  | true  | :job_token             | false | :unauthorized
      :private | :guest      | true  | :job_token             | false | :unauthorized
      :private | :developer  | false | :job_token             | true  | :not_found
      :private | :guest      | false | :job_token             | true  | :not_found
      :private | :developer  | false | :job_token             | false | :unauthorized
      :private | :guest      | false | :job_token             | false | :unauthorized
      :public  | :developer  | true  | :deploy_token          | true  | :success
      :public  | :developer  | true  | :deploy_token          | false | :unauthorized
      :private | :developer  | true  | :deploy_token          | true  | :success
      :private | :developer  | true  | :deploy_token          | false | :unauthorized
    end

    # :visibility, :user_role, :member, :token_type, :valid_token, :expected_status
    def download_permissions_tables
      :public  | :developer  | true  | :personal_access_token | true  |  :success
      :public  | :guest      | true  | :personal_access_token | true  |  :success
      :public  | :developer  | true  | :personal_access_token | false |  :unauthorized
      :public  | :guest      | true  | :personal_access_token | false |  :unauthorized
      :public  | :developer  | false | :personal_access_token | true  |  :success
      :public  | :guest      | false | :personal_access_token | true  |  :success
      :public  | :developer  | false | :personal_access_token | false |  :unauthorized
      :public  | :guest      | false | :personal_access_token | false |  :unauthorized
      :public  | :anonymous  | false | :personal_access_token | true  |  :success
      :private | :developer  | true  | :personal_access_token | true  |  :success
      :private | :guest      | true  | :personal_access_token | true  |  :forbidden
      :private | :developer  | true  | :personal_access_token | false |  :unauthorized
      :private | :guest      | true  | :personal_access_token | false |  :unauthorized
      :private | :developer  | false | :personal_access_token | true | :not_found
      :private | :guest      | false | :personal_access_token | true  |  :not_found
      :private | :developer  | false | :personal_access_token | false |  :unauthorized
      :private | :guest      | false | :personal_access_token | false |  :unauthorized
      :private | :anonymous  | false | :personal_access_token | true  |  :not_found
      :public  | :developer  | true  | :job_token             | true  |  :success
      :public  | :guest      | true  | :job_token             | true  |  :success
      :public  | :developer  | true  | :job_token             | false |  :unauthorized
      :public  | :guest      | true  | :job_token             | false |  :unauthorized
      :public  | :developer  | false | :job_token             | true  |  :success
      :public  | :guest      | false | :job_token             | true  |  :success
      :public  | :developer  | false | :job_token             | false |  :unauthorized
      :public  | :guest      | false | :job_token             | false |  :unauthorized
      :private | :developer  | true  | :job_token             | true  |  :success
      :private | :guest      | true  | :job_token             | true  |  :forbidden
      :private | :developer  | true  | :job_token             | false |  :unauthorized
      :private | :guest      | true  | :job_token             | false |  :unauthorized
      :private | :developer  | false | :job_token             | true  |  :not_found
      :private | :guest      | false | :job_token             | true  |  :not_found
      :private | :developer  | false | :job_token             | false |  :unauthorized
      :private | :guest      | false | :job_token             | false |  :unauthorized
      :public  | :developer  | true  | :deploy_token          | true  |  :success
      :public  | :developer  | true  | :deploy_token          | false |  :unauthorized
      :private | :developer  | true  | :deploy_token          | true  |  :success
      :private | :developer  | true  | :deploy_token          | false |  :unauthorized
    end
    # rubocop:enable Metrics/AbcSize
  end

  before do
    project.send("add_#{user_role}", user) if member && user_role != :anonymous
  end

  describe 'PUT /api/v4/projects/:id/packages/ml_models/:model_name/:model_version/:file_name/authorize' do
    include_context 'ml model authorize permissions table'

    let(:token) { tokens[:personal_access_token] }
    let(:user_headers) { { 'HTTP_AUTHORIZATION' => token } }
    let(:headers) { user_headers.merge(workhorse_headers) }
    let(:request) { authorize_upload_file(headers) }
    let(:model_name) { 'my_package' }
    let(:file_name) { 'myfile.tar.gz' }

    subject(:api_response) do
      url = "/projects/#{project.id}/packages/ml_models/#{model_name}/0.0.1/#{file_name}/authorize"

      put api(url), headers: headers

      response
    end

    describe 'user access' do
      where(:visibility, :user_role, :member, :token_type, :valid_token, :expected_status) do
        authorize_permissions_table
      end

      with_them do
        let(:token) { valid_token ? tokens[token_type] : 'invalid-token123' }
        let(:user_headers) { user_role == :anonymous ? {} : { 'HTTP_AUTHORIZATION' => token } }

        before do
          project.update_column(:visibility_level, Gitlab::VisibilityLevel.level_value(visibility.to_s))
        end

        it { is_expected.to have_gitlab_http_status(expected_status) }
      end

      it_behaves_like 'Endpoint not found if read_model_registry not available'
    end

    describe 'application security' do
      where(:model_name, :file_name) do
        'my-package/../'         | 'myfile.tar.gz'
        'my-package%2f%2e%2e%2f' | 'myfile.tar.gz'
        'my_package'             | '../.ssh%2fauthorized_keys'
        'my_package'             | '%2e%2e%2f.ssh%2fauthorized_keys'
      end

      with_them do
        it 'rejects malicious request' do
          is_expected.to have_gitlab_http_status(:bad_request)
        end
      end
    end
  end

  describe 'PUT /api/v4/projects/:id/packages/ml_models/:model_name/:model_version/:file_name' do
    include_context 'ml model authorize permissions table'

    let_it_be(:file_name) { 'model.md5' }

    let(:token) { tokens[:personal_access_token] }
    let(:user_headers) { { 'HTTP_AUTHORIZATION' => token } }
    let(:headers) { user_headers.merge(workhorse_headers) }
    let(:params) { { file: temp_file(file_name) } }
    let(:file_key) { :file }
    let(:send_rewritten_field) { true }
    let(:model_name) { 'my_package' }

    subject(:api_response) do
      url = "/projects/#{project.id}/packages/ml_models/#{model_name}/0.0.1/#{file_name}"

      workhorse_finalize(
        api(url),
        method: :put,
        file_key: file_key,
        params: params,
        headers: headers,
        send_rewritten_field: send_rewritten_field
      )

      response
    end

    describe 'success' do
      it 'creates a new package' do
        expect { api_response }.to change { Packages::PackageFile.count }.by(1)
        expect(api_response).to have_gitlab_http_status(:created)
      end
    end

    describe 'user access' do
      where(:visibility, :user_role, :member, :token_type, :valid_token, :expected_status) do
        authorize_permissions_table
      end

      with_them do
        let(:token) { valid_token ? tokens[token_type] : 'invalid-token123' }
        let(:user_headers) { user_role == :anonymous ? {} : { 'HTTP_AUTHORIZATION' => token } }

        before do
          project.update_column(:visibility_level, Gitlab::VisibilityLevel.level_value(visibility.to_s))
        end

        if params[:expected_status] == :success
          it_behaves_like 'process ml model package upload'
        else
          it { is_expected.to have_gitlab_http_status(expected_status) }
        end
      end

      it_behaves_like 'Endpoint not found if read_model_registry not available'
    end
  end

  describe 'GET /api/v4/projects/:project_id/packages/ml_models/:model_name/:model_version/:file_name' do
    include_context 'ml model authorize permissions table'

    let_it_be(:package) { create(:ml_model_package, project: project, name: 'model', version: '0.0.1') }
    let_it_be(:package_file) { create(:package_file, :generic, package: package, file_name: 'model.md5') }

    let(:model_name) { package.name }
    let(:model_version) { package.version }
    let(:file_name) { package_file.file_name }

    let(:token) { tokens[:personal_access_token] }
    let(:user_headers) { { 'HTTP_AUTHORIZATION' => token } }
    let(:headers) { user_headers.merge(workhorse_headers) }

    subject(:api_response) do
      url = "/projects/#{project.id}/packages/ml_models/#{model_name}/#{model_version}/#{file_name}"

      get api(url), headers: headers

      response
    end

    describe 'user access' do
      where(:visibility, :user_role, :member, :token_type, :valid_token, :expected_status) do
        download_permissions_tables
      end

      with_them do
        let(:token) { valid_token ? tokens[token_type] : 'invalid-token123' }
        let(:user_headers) { user_role == :anonymous ? {} : { 'HTTP_AUTHORIZATION' => token } }

        before do
          project.update_column(:visibility_level, Gitlab::VisibilityLevel.level_value(visibility.to_s))
        end

        if params[:expected_status] == :success
          it_behaves_like 'process ml model package download'
        else
          it { is_expected.to have_gitlab_http_status(expected_status) }
        end
      end

      it_behaves_like 'Endpoint not found if read_model_registry not available'
    end
  end
end
