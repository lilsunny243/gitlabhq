# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GonHelper do
  let(:helper) do
    Class.new do
      include Gitlab::GonHelper
    end.new
  end

  describe '#add_gon_variables' do
    let(:gon) { double('gon').as_null_object }
    let(:https) { true }

    before do
      allow(helper).to receive(:current_user).and_return(nil)
      allow(helper).to receive(:gon).and_return(gon)
      stub_config_setting(https: https)
    end

    context 'when HTTPS is enabled' do
      it 'sets the secure flag to true' do
        expect(gon).to receive(:secure=).with(true)

        helper.add_gon_variables
      end
    end

    context 'when HTTP is enabled' do
      let(:https) { false }

      it 'sets the secure flag to false' do
        expect(gon).to receive(:secure=).with(false)

        helper.add_gon_variables
      end
    end

    it 'sets no GitLab version' do
      expect(gon).not_to receive(:version=)

      helper.add_gon_variables
    end

    context 'when user is logged in' do
      before do
        allow(helper).to receive(:current_user).and_return(build_stubbed(:user))
      end

      it 'sets GitLab version' do
        expect(gon).to receive(:version=).with(Gitlab::VERSION)

        helper.add_gon_variables
      end
    end

    context 'when sentry is configured' do
      let(:clientside_dsn) { 'https://xxx@sentry.example.com/1' }
      let(:environment) { 'staging' }
      let(:sentry_clientside_traces_sample_rate) { 0.5 }

      context 'with legacy sentry configuration' do
        before do
          stub_config(sentry: { enabled: true, clientside_dsn: clientside_dsn, environment: environment })
        end

        it 'sets sentry dsn and environment from config' do
          expect(gon).to receive(:sentry_dsn=).with(clientside_dsn)
          expect(gon).to receive(:sentry_environment=).with(environment)

          helper.add_gon_variables
        end
      end

      context 'with sentry settings' do
        before do
          stub_application_setting(sentry_enabled: true)
          stub_application_setting(sentry_clientside_dsn: clientside_dsn)
          stub_application_setting(sentry_environment: environment)
          stub_application_setting(sentry_clientside_traces_sample_rate: sentry_clientside_traces_sample_rate)
        end

        it 'sets sentry dsn and environment from config' do
          expect(gon).to receive(:sentry_dsn=).with(clientside_dsn)
          expect(gon).to receive(:sentry_environment=).with(environment)
          expect(gon).to receive(:sentry_clientside_traces_sample_rate=).with(sentry_clientside_traces_sample_rate)

          helper.add_gon_variables
        end

        context 'when enable_new_sentry_clientside_integration is disabled' do
          before do
            stub_feature_flags(enable_new_sentry_clientside_integration: false)
          end

          it 'does not set sentry dsn and environment from config' do
            expect(gon).not_to receive(:sentry_dsn=).with(clientside_dsn)
            expect(gon).not_to receive(:sentry_environment=).with(environment)
            expect(gon).not_to receive(:sentry_clientside_traces_sample_rate=)
              .with(sentry_clientside_traces_sample_rate)

            helper.add_gon_variables
          end
        end
      end
    end
  end

  describe '#push_frontend_feature_flag' do
    before do
      skip_feature_flags_yaml_validation
      skip_default_enabled_yaml_check
    end

    it 'pushes a feature flag to the frontend' do
      gon = class_double('Gon')
      thing = stub_feature_flag_gate('thing')

      stub_feature_flags(my_feature_flag: thing)
      stub_feature_flag_definition(:my_feature_flag)

      allow(helper)
        .to receive(:gon)
        .and_return(gon)

      expect(gon)
        .to receive(:push)
        .with({ features: { 'myFeatureFlag' => true } }, true)

      helper.push_frontend_feature_flag(:my_feature_flag, thing)
    end
  end

  describe '#push_force_frontend_feature_flag' do
    let(:gon) { class_double('Gon') }

    before do
      skip_feature_flags_yaml_validation

      allow(helper)
        .to receive(:gon)
        .and_return(gon)
    end

    it 'pushes a feature flag to the frontend with the provided value' do
      expect(gon)
        .to receive(:push)
        .with({ features: { 'myFeatureFlag' => true } }, true)

      helper.push_force_frontend_feature_flag(:my_feature_flag, true)
    end

    it 'pushes a disabled feature flag if provided value is nil' do
      expect(gon)
        .to receive(:push)
        .with({ features: { 'myFeatureFlag' => false } }, true)

      helper.push_force_frontend_feature_flag(:my_feature_flag, nil)
    end
  end

  describe '#default_avatar_url' do
    it 'returns an absolute URL' do
      url = helper.default_avatar_url

      expect(url).to match(/^http/)
      expect(url).to match(/no_avatar.*png$/)
    end
  end

  describe '#add_browsersdk_tracking' do
    let(:gon) { double('gon').as_null_object }
    let(:analytics_url) { 'https://analytics.gitlab.com' }
    let(:is_gitlab_com) { true }

    before do
      allow(helper).to receive(:gon).and_return(gon)
      allow(Gitlab).to receive(:com?).and_return(is_gitlab_com)
    end

    context 'when environment variables are set' do
      before do
        stub_env('GITLAB_ANALYTICS_URL', analytics_url)
        stub_env('GITLAB_ANALYTICS_ID', 'analytics-id')
      end

      it 'sets the analytics_url and analytics_id' do
        expect(gon).to receive(:analytics_url=).with(analytics_url)
        expect(gon).to receive(:analytics_id=).with('analytics-id')

        helper.add_browsersdk_tracking
      end

      context 'when Gitlab.com? is false' do
        let(:is_gitlab_com) { false }

        it "doesn't set the analytics_url and analytics_id" do
          expect(gon).not_to receive(:analytics_url=)
          expect(gon).not_to receive(:analytics_id=)

          helper.add_browsersdk_tracking
        end
      end

      context 'when feature flag is false' do
        before do
          stub_feature_flags(browsersdk_tracking: false)
        end

        it "doesn't set the analytics_url and analytics_id" do
          expect(gon).not_to receive(:analytics_url=)
          expect(gon).not_to receive(:analytics_id=)

          helper.add_browsersdk_tracking
        end
      end
    end

    context 'when environment variables are not set' do
      before do
        stub_env('GITLAB_ANALYTICS_URL', nil)
        stub_env('GITLAB_ANALYTICS_ID', nil)
      end

      it "doesn't set the analytics_url and analytics_id" do
        expect(gon).not_to receive(:analytics_url=)
        expect(gon).not_to receive(:analytics_id=)

        helper.add_browsersdk_tracking
      end
    end
  end
end
