# frozen_string_literal: true

module VsCode
  class VsCodeSetting < ApplicationRecord
    belongs_to :user, inverse_of: :vscode_settings

    validates :setting_type, presence: true
    validates :content, presence: true

    scope :by_setting_type, ->(setting_type) { where(setting_type: setting_type) }
    scope :by_user, ->(user) { where(user: user) }
  end
end
