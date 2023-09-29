# frozen_string_literal: true

module Sidebars
  module Organizations
    module Menus
      class ScopeMenu < ::Sidebars::Menu
        override :link
        def link
          organization_path(context.container)
        end

        override :title
        def title
          context.container.name
        end

        override :active_routes
        def active_routes
          { path: 'organizations/organizations#show' }
        end

        override :render?
        def render?
          true
        end

        override :extra_nav_link_html_options
        def extra_nav_link_html_options
          {
            class: 'context-header'
          }
        end

        override :serialize_as_menu_item_args
        def serialize_as_menu_item_args
          super.merge({
            avatar: nil,
            entity_id: context.container.id,
            super_sidebar_parent: ::Sidebars::StaticMenu,
            item_id: :organization_overview
          })
        end
      end
    end
  end
end
