# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SidebarsHelper, feature_category: :navigation do
  include Devise::Test::ControllerHelpers

  describe '#sidebar_tracking_attributes_by_object' do
    subject(:tracking_attrs) { helper.sidebar_tracking_attributes_by_object(object) }

    before do
      stub_application_setting(snowplow_enabled: true)
    end

    context 'when object is a project' do
      let(:object) { build(:project) }

      it 'returns tracking attrs for project' do
        attrs = {
          track_label: 'projects_side_navigation',
          track_property: 'projects_side_navigation',
          track_action: 'render'
        }

        expect(tracking_attrs[:data]).to eq(attrs)
      end
    end

    context 'when object is a group' do
      let(:object) { build(:group) }

      it 'returns tracking attrs for group' do
        attrs = {
          track_label: 'groups_side_navigation',
          track_property: 'groups_side_navigation',
          track_action: 'render'
        }

        expect(tracking_attrs[:data]).to eq(attrs)
      end
    end

    context 'when object is a user' do
      let(:object) { build(:user) }

      it 'returns tracking attrs for user' do
        attrs = {
          track_label: 'user_side_navigation',
          track_property: 'user_side_navigation',
          track_action: 'render'
        }

        expect(tracking_attrs[:data]).to eq(attrs)
      end
    end

    context 'when object is something else' do
      let(:object) { build(:ci_pipeline) }

      it { is_expected.to eq({}) }
    end
  end

  describe '#super_sidebar_context' do
    let_it_be(:user) { build(:user) }
    let_it_be(:group) { build(:group) }
    let_it_be(:panel) { {} }

    subject do
      helper.super_sidebar_context(user, group: group, project: nil, panel: panel)
    end

    before do
      allow(helper).to receive(:current_user) { user }
      allow(helper).to receive(:can?).and_return(true)
      allow(panel).to receive(:super_sidebar_menu_items).and_return(nil)
      allow(panel).to receive(:super_sidebar_context_header).and_return(nil)
      allow(user).to receive(:assigned_open_issues_count).and_return(1)
      allow(user).to receive(:assigned_open_merge_requests_count).and_return(4)
      allow(user).to receive(:review_requested_open_merge_requests_count).and_return(0)
      allow(user).to receive(:todos_pending_count).and_return(3)
      allow(user).to receive(:total_merge_requests_count).and_return(4)
    end

    it 'returns sidebar values from user', :use_clean_rails_memory_store_caching do
      expect(subject).to include({
        current_context_header: nil,
        current_menu_items: nil,
        name: user.name,
        username: user.username,
        avatar_url: user.avatar_url,
        has_link_to_profile: helper.current_user_menu?(:profile),
        link_to_profile: user_url(user),
        status: {
          can_update: helper.can?(user, :update_user_status, user),
          busy: user.status&.busy?,
          customized: user.status&.customized?,
          availability: user.status&.availability.to_s,
          emoji: user.status&.emoji,
          message: user.status&.message_html&.html_safe,
          clear_after: user.status&.clear_status_at.to_s
        },
        trial: {
          has_start_trial: helper.current_user_menu?(:start_trial),
          url: helper.trials_link_url
        },
        settings: {
          has_settings: helper.current_user_menu?(:settings),
          profile_path: profile_path,
          profile_preferences_path: profile_preferences_path
        },
        can_sign_out: helper.current_user_menu?(:sign_out),
        sign_out_link: destroy_user_session_path,
        assigned_open_issues_count: 1,
        todos_pending_count: 3,
        issues_dashboard_path: issues_dashboard_path(assignee_username: user.username),
        total_merge_requests_count: 4,
        support_path: helper.support_url,
        display_whats_new: helper.display_whats_new?,
        whats_new_most_recent_release_items_count: helper.whats_new_most_recent_release_items_count,
        whats_new_version_digest: helper.whats_new_version_digest,
        show_version_check: helper.show_version_check?,
        gitlab_version: Gitlab.version_info,
        gitlab_version_check: helper.gitlab_version_check,
        gitlab_com_but_not_canary: Gitlab.com_but_not_canary?,
        gitlab_com_and_canary: Gitlab.com_and_canary?,
        canary_toggle_com_url: Gitlab::Saas.canary_toggle_com_url
      })
    end

    it 'returns "Merge requests" menu', :use_clean_rails_memory_store_caching do
      expect(subject[:merge_request_menu]).to eq([
        {
          name: _('Merge requests'),
          items: [
            {
              text: _('Assigned'),
              href: merge_requests_dashboard_path(assignee_username: user.username),
              count: 4
            },
            {
              text: _('Review requests'),
              href: merge_requests_dashboard_path(reviewer_username: user.username),
              count: 0
            }
          ]
        }
      ])
    end

    it 'returns "Create new" menu groups without headers', :use_clean_rails_memory_store_caching do
      expect(subject[:create_new_menu_groups]).to eq([
        {
          name: "",
          items: [
            { href: "/projects/new", text: "New project/repository" },
            { href: "/groups/new", text: "New group" },
            { href: "/-/snippets/new", text: "New snippet" }
          ]
        }
      ])
    end

    it 'returns "Create new" menu groups with headers', :use_clean_rails_memory_store_caching do
      allow(group).to receive(:persisted?).and_return(true)
      allow(helper).to receive(:can?).and_return(true)

      expect(subject[:create_new_menu_groups]).to contain_exactly(
        a_hash_including(
          name: "In this group",
          items: array_including(
            { href: "/projects/new", text: "New project/repository" },
            { href: "/groups/new#create-group-pane", text: "New subgroup" },
            { href: '', text: "Invite members" }
          )
        ),
        a_hash_including(
          name: "In GitLab",
          items: array_including(
            { href: "/projects/new", text: "New project/repository" },
            { href: "/groups/new", text: "New group" },
            { href: "/-/snippets/new", text: "New snippet" }
          )
        )
      )
    end
  end

  describe '#super_sidebar_nav_panel' do
    let(:user) { build(:user) }
    let(:group) { build(:group) }
    let(:project) { build(:project) }

    before do
      allow(helper).to receive(:project_sidebar_context_data).and_return(
        { current_user: nil, container: project, can_view_pipeline_editor: false, learn_gitlab_enabled: false })
      allow(helper).to receive(:group_sidebar_context_data).and_return({ current_user: nil, container: group })

      allow(group).to receive(:to_global_id).and_return(5)
      Rails.cache.write(['users', user.id, 'assigned_open_issues_count'], 1)
      Rails.cache.write(['users', user.id, 'assigned_open_merge_requests_count'], 4)
      Rails.cache.write(['users', user.id, 'review_requested_open_merge_requests_count'], 0)
      Rails.cache.write(['users', user.id, 'todos_pending_count'], 3)
      Rails.cache.write(['users', user.id, 'total_merge_requests_count'], 4)
    end

    it 'returns Project Panel for project nav' do
      expect(helper.super_sidebar_nav_panel(nav: 'project')).to be_a(Sidebars::Projects::SuperSidebarPanel)
    end

    it 'returns Group Panel for group nav' do
      expect(helper.super_sidebar_nav_panel(nav: 'group')).to be_a(Sidebars::Groups::Panel)
    end

    it 'returns "Your Work" Panel for your_work nav', :use_clean_rails_memory_store_caching do
      expect(helper.super_sidebar_nav_panel(nav: 'your_work', user: user)).to be_a(Sidebars::YourWork::Panel)
    end

    it 'returns "Your Work" Panel as a fallback', :use_clean_rails_memory_store_caching do
      expect(helper.super_sidebar_nav_panel(user: user)).to be_a(Sidebars::YourWork::Panel)
    end
  end
end
