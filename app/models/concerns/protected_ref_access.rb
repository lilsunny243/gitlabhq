# frozen_string_literal: true

module ProtectedRefAccess
  extend ActiveSupport::Concern

  class_methods do
    def human_access_levels
      {
        Gitlab::Access::DEVELOPER => 'Developers + Maintainers',
        Gitlab::Access::MAINTAINER => 'Maintainers',
        Gitlab::Access::ADMIN => 'Instance admins',
        Gitlab::Access::NO_ACCESS => 'No one'
      }.slice(*allowed_access_levels)
    end

    def allowed_access_levels
      levels = [
        Gitlab::Access::DEVELOPER,
        Gitlab::Access::MAINTAINER,
        Gitlab::Access::ADMIN,
        Gitlab::Access::NO_ACCESS
      ]

      return levels unless Gitlab.com?

      levels.excluding(Gitlab::Access::ADMIN)
    end

    def humanize(access_level)
      human_access_levels[access_level]
    end

    def non_role_types
      []
    end
  end

  included do
    scope :maintainer, -> { where(access_level: Gitlab::Access::MAINTAINER) }
    scope :developer, -> { where(access_level: Gitlab::Access::DEVELOPER) }
    scope :for_role, -> {
      if non_role_types.present?
        where.missing(*non_role_types)
          .allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/417457")
      else
        all
      end
    }

    protected_ref_fk = "#{module_parent.model_name.singular}_id"
    validates :access_level,
      presence: true,
      inclusion: { in: allowed_access_levels },
      uniqueness: { scope: protected_ref_fk, conditions: -> { for_role } },
      if: :role?
  end

  def humanize
    self.class.humanize(access_level)
  end

  def type
    :role
  end

  def role?
    type == :role
  end

  def check_access(current_user)
    return false if current_user.nil? || no_access?
    return current_user.admin? if admin_access?

    yield if block_given?

    user_can_access?(current_user)
  end

  private

  def admin_access?
    role? && access_level == ::Gitlab::Access::ADMIN
  end

  def no_access?
    role? && access_level == Gitlab::Access::NO_ACCESS
  end

  def user_can_access?(current_user)
    current_user.can?(:push_code, project) &&
      project.team.max_member_access(current_user.id) >= access_level
  end
end

ProtectedRefAccess.include_mod_with('ProtectedRefAccess::Scopes')
ProtectedRefAccess.prepend_mod_with('ProtectedRefAccess')

# When using `prepend` (or `include` for that matter), the `ClassMethods`
# constants are not merged. This means that `class_methods` in
# `EE::ProtectedRefAccess` would be ignored.
#
# To work around this, we prepend the `ClassMethods` constant manually.
ProtectedRefAccess::ClassMethods.prepend_mod_with('ProtectedRefAccess::ClassMethods')
