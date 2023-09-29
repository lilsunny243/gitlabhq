# frozen_string_literal: true

module Pajamas
  class EmptyStateComponent < Pajamas::Component
    # @param [Boolean] compact
    # @param [String] title
    # @param [String] svg_path
    # @param [String] primary_button_text
    # @param [String] primary_button_link
    # @param [String] secondary_button_text
    # @param [String] secondary_button_link
    # @param [Hash] empty_state_options
    def initialize(
      compact: false,
      title: nil,
      svg_path: nil,
      primary_button_text: nil,
      primary_button_link: nil,
      secondary_button_text: nil,
      secondary_button_link: nil,
      empty_state_options: {}
    )
      @compact = compact
      @title = title
      @svg_path = svg_path.to_s
      @primary_button_text = primary_button_text
      @primary_button_link = primary_button_link
      @secondary_button_text = secondary_button_text
      @secondary_button_link = secondary_button_link
      @empty_state_options = empty_state_options
    end

    renders_one :description
  end
end
