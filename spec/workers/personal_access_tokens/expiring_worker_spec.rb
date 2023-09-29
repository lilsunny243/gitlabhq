# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::ExpiringWorker, type: :worker, feature_category: :system_access do
  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'when a token needs to be notified' do
      let_it_be(:user) { create(:user) }
      let_it_be(:expiring_token) { create(:personal_access_token, user: user, expires_at: 5.days.from_now) }
      let_it_be(:expiring_token2) { create(:personal_access_token, user: user, expires_at: 3.days.from_now) }
      let_it_be(:notified_token) { create(:personal_access_token, user: user, expires_at: 5.days.from_now, expire_notification_delivered: true) }
      let_it_be(:not_expiring_token) { create(:personal_access_token, user: user, expires_at: 1.month.from_now) }
      let_it_be(:impersonation_token) { create(:personal_access_token, user: user, expires_at: 5.days.from_now, impersonation: true) }

      it 'uses notification service to send the email' do
        expect_next_instance_of(NotificationService) do |notification_service|
          expect(notification_service).to receive(:access_token_about_to_expire).with(user, match_array([expiring_token.name, expiring_token2.name]))
        end

        worker.perform
      end

      it 'marks the notification as delivered' do
        expect { worker.perform }.to change { expiring_token.reload.expire_notification_delivered }.from(false).to(true)
      end
    end

    context 'when no tokens need to be notified' do
      let_it_be(:pat) { create(:personal_access_token, expires_at: 5.days.from_now, expire_notification_delivered: true) }

      it "doesn't use notification service to send the email" do
        expect_next_instance_of(NotificationService) do |notification_service|
          expect(notification_service).not_to receive(:access_token_about_to_expire).with(pat.user, [pat.name])
        end

        worker.perform
      end

      it "doesn't change the notification delivered of the token" do
        expect { worker.perform }.not_to change { pat.reload.expire_notification_delivered }
      end
    end

    context 'when a token is an impersonation token' do
      let_it_be(:pat) { create(:personal_access_token, :impersonation, expires_at: 5.days.from_now) }

      it "doesn't use notification service to send the email" do
        expect_next_instance_of(NotificationService) do |notification_service|
          expect(notification_service).not_to receive(:access_token_about_to_expire).with(pat.user, [pat.name])
        end

        worker.perform
      end

      it "doesn't change the notification delivered of the token" do
        expect { worker.perform }.not_to change { pat.reload.expire_notification_delivered }
      end
    end

    context 'when a token is owned by a project bot' do
      let_it_be(:maintainer1) { create(:user) }
      let_it_be(:maintainer2) { create(:user) }
      let_it_be(:project_bot) { create(:user, :project_bot) }
      let_it_be(:project) { create(:project) }
      let_it_be(:expiring_token) { create(:personal_access_token, user: project_bot, expires_at: 5.days.from_now) }

      before_all do
        project.add_developer(project_bot)
        project.add_maintainer(maintainer1)
        project.add_maintainer(maintainer2)
      end

      it 'uses notification service to send the email' do
        expect_next_instance_of(NotificationService) do |notification_service|
          expect(notification_service).to receive(:resource_access_tokens_about_to_expire)
                                            .with(project_bot, match_array([expiring_token.name]))
        end

        worker.perform
      end

      it 'marks the notification as delivered' do
        expect { worker.perform }.to change { expiring_token.reload.expire_notification_delivered }.from(false).to(true)
      end
    end
  end
end
