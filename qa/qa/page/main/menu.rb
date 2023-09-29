# frozen_string_literal: true

module QA
  module Page
    module Main
      class Menu < Page::Base
        # We need to check phone_layout? instead of mobile_layout? here
        # since tablets have the regular top navigation bar
        prepend Mobile::Page::Main::Menu if Runtime::Env.phone_layout?
        include SubMenus::CreateNewMenu
        include SubMenus::SuperSidebar::GlobalSearchModal

        view 'app/assets/javascripts/super_sidebar/components/super_sidebar.vue' do
          element :navbar, required: true # TODO: rename to sidebar once it's default implementation
        end

        view 'app/assets/javascripts/super_sidebar/components/user_menu.vue' do
          element 'user-dropdown', required: !Runtime::Env.phone_layout?
          element :user_avatar_content, required: !Runtime::Env.phone_layout?
          element :sign_out_link
          element :edit_profile_link
        end

        view 'app/assets/javascripts/super_sidebar/components/user_name_group.vue' do
          element :user_profile_link
        end

        view 'app/assets/javascripts/super_sidebar/components/user_bar.vue' do
          element 'stop-impersonation-btn'
          element 'issues-shortcut-button', required: !Runtime::Env.phone_layout?
          element 'merge-requests-shortcut-button', required: !Runtime::Env.phone_layout?
          element 'todos-shortcut-button', required: !Runtime::Env.phone_layout?
        end

        view 'app/assets/javascripts/super_sidebar/components/global_search/components/global_search.vue' do
          element 'global-search-input'
        end

        view 'app/assets/javascripts/nav/components/top_nav_app.vue' do
          element :navbar_dropdown
        end

        view 'app/assets/javascripts/nav/components/top_nav_dropdown_menu.vue' do
          element 'menu-subview'
        end

        view 'lib/gitlab/nav/top_nav_menu_item.rb' do
          element :menu_item_link
        end

        view 'app/helpers/nav/top_nav_helper.rb' do
          element :admin_area_link
          element :projects_dropdown
          element :groups_dropdown
          element :menu_item_link
        end

        view 'app/views/layouts/_header_search.html.haml' do
          element :search_box
        end

        view 'app/assets/javascripts/header_search/components/app.vue' do
          element 'global-search-input'
        end

        view 'app/views/layouts/header/_new_dropdown.html.haml' do
          element 'new-menu-toggle'
        end

        view 'app/helpers/nav/new_dropdown_helper.rb' do
          element :global_new_group_link
          element :global_new_project_link
          element :global_new_snippet_link
        end

        view 'app/assets/javascripts/nav/components/new_nav_toggle.vue' do
          element :new_navigation_toggle
        end

        def go_to_projects
          click_element(:nav_item_link, submenu_item: 'Projects')
        end

        def go_to_groups
          # This needs to be fixed in the tests themselves. Fullfillment tests try to go to groups view from the
          # group. Instead of having a global hack, explicit test should navigate to correct view first.
          # see: https://gitlab.com/gitlab-org/gitlab/-/issues/403589#note_1383040061
          go_to_your_work unless has_element?(:nav_item_link, submenu_item: 'Groups', wait: 0)
          click_element(:nav_item_link, submenu_item: 'Groups')
        end

        def go_to_snippets
          click_element(:nav_item_link, submenu_item: 'Snippets')
        end

        def go_to_workspaces
          click_element(:nav_item_link, submenu_item: 'Workspaces')
        end

        def go_to_menu_dropdown_option(option_name)
          click_element(option_name)
        end

        def go_to_todos
          click_element('todos-shortcut-button')
        end

        def signed_in?
          return false if Page::Main::Login.perform(&:on_login_page?)

          has_personal_area?(wait: 0)
        end

        def signed_in_as_user?(user)
          return false unless has_personal_area?

          within_user_menu do
            has_element?(:user_profile_link, text: /#{user.username}/)
          end
          # we need to close user menu because plain user link check will leave it open
          click_element :user_avatar_content if has_element?(:user_profile_link, wait: 0)
        end

        def not_signed_in?
          return true if Page::Main::Login.perform(&:on_login_page?)

          has_no_personal_area?
        end

        def sign_out
          close_global_search_modal_if_shown

          retry_until do
            wait_if_retry_later

            break true unless signed_in?

            within_user_menu do
              click_element :sign_out_link
            end

            not_signed_in?
          end
        end

        def sign_out_if_signed_in
          sign_out if signed_in?
        end

        def click_edit_profile_link
          retry_until(reload: false) do
            within_user_menu do
              click_element(:edit_profile_link)
            end

            has_text?('User Settings')
          end
        end

        def click_user_profile_link
          within_user_menu do
            click_element(:user_profile_link)
          end
        end

        def has_personal_area?(wait: Capybara.default_max_wait_time)
          has_element?(:user_avatar_content, wait: wait)
        end

        def has_no_personal_area?(wait: Capybara.default_max_wait_time)
          has_no_element?(:user_avatar_content, wait: wait)
        end

        def click_stop_impersonation_link
          click_element('stop-impersonation-btn')
        end

        # To verify whether the user has been directed to a canary web node
        # @return [Boolean] result of checking existence of :canary_badge_link element
        # @example:
        #   Menu.perform do |menu|
        #     expect(menu.canary?).to be(true)
        #   end
        def canary?
          has_element?(:canary_badge_link)
        end

        private

        def within_user_menu(&block)
          within_element(:navbar) do
            click_element :user_avatar_content unless has_element?(:user_profile_link, wait: 1)

            within_element('user-dropdown', &block)
          end
        end
      end
    end
  end
end

QA::Page::Main::Menu.prepend_mod_with('Page::Main::Menu', namespace: QA)
