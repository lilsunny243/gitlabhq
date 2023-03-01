# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::Runner, :clean_gitlab_redis_shared_state, feature_category: :runner do
  include StubGitlabCalls
  include RedisHelpers
  include WorkhorseHelpers

  let(:registration_token) { 'abcdefg123456' }

  before do
    stub_feature_flags(ci_enable_live_trace: true)
    stub_gitlab_calls
    stub_application_setting(runners_registration_token: registration_token)
    allow_any_instance_of(::Ci::Runner).to receive(:cache_attributes)
  end

  describe '/api/v4/runners' do
    describe 'POST /api/v4/runners/verify' do
      let_it_be_with_reload(:runner) { create(:ci_runner, token_expires_at: 3.days.from_now) }

      let(:params) {}

      subject(:verify) { post api('/runners/verify'), params: params }

      context 'when no token is provided' do
        it 'returns 400 error' do
          post api('/runners/verify')

          expect(response).to have_gitlab_http_status :bad_request
        end
      end

      context 'when invalid token is provided' do
        let(:params) { { token: 'invalid-token' } }

        it 'returns 403 error' do
          verify

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when valid token is provided' do
        let(:params) { { token: runner.token } }

        context 'with create_runner_machine FF enabled' do
          before do
            stub_feature_flags(create_runner_machine: true)
          end

          it 'verifies Runner credentials' do
            verify

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({
              'id' => runner.id,
              'token' => runner.token,
              'token_expires_at' => runner.token_expires_at.iso8601(3)
            })
          end

          context 'with non-expiring runner token' do
            before do
              runner.update!(token_expires_at: nil)
            end

            it 'verifies Runner credentials' do
              verify

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response).to eq({
                'id' => runner.id,
                'token' => runner.token,
                'token_expires_at' => nil
              })
            end
          end

          it_behaves_like 'storing arguments in the application context for the API' do
            let(:expected_params) { { client_id: "runner/#{runner.id}" } }
          end

          context 'when system_id is provided' do
            let(:params) { { token: runner.token, system_id: 's_some_system_id' } }

            it 'creates a runner_machine' do
              expect { verify }.to change { Ci::RunnerMachine.count }.by(1)
            end
          end
        end

        context 'with create_runner_machine FF disabled' do
          before do
            stub_feature_flags(create_runner_machine: false)
          end

          it 'verifies Runner credentials' do
            verify

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({
              'id' => runner.id,
              'token' => runner.token,
              'token_expires_at' => runner.token_expires_at.iso8601(3)
            })
          end

          context 'when system_id is provided' do
            let(:params) { { token: runner.token, system_id: 's_some_system_id' } }

            it 'does not create a runner_machine', :aggregate_failures do
              expect { verify }.not_to change { Ci::RunnerMachine.count }

              expect(response).to have_gitlab_http_status(:ok)
            end
          end
        end
      end

      context 'when non-expired token is provided' do
        let(:params) { { token: runner.token } }

        it 'verifies Runner credentials' do
          runner["token_expires_at"] = 10.days.from_now
          runner.save!
          verify

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({
            'id' => runner.id,
            'token' => runner.token,
            'token_expires_at' => runner.token_expires_at.iso8601(3)
          })
        end
      end

      context 'when expired token is provided' do
        let(:params) { { token: runner.token } }

        it 'does not verify Runner credentials' do
          runner["token_expires_at"] = 10.days.ago
          runner.save!
          verify

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end
end
