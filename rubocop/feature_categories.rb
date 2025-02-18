# frozen_string_literal: true

require 'set'
require 'yaml'
require 'digest/sha2'
require 'did_you_mean'

module RuboCop
  class FeatureCategories
    MSG = 'Please use a valid feature category. %{msg_suggestion}' \
          'See %{document_link}'

    MSG_DID_YOU_MEAN = 'Did you mean `:%{suggestion}`? '

    MSG_SYMBOL = 'Please use a symbol as value.'

    CONFIG_PATH = File.expand_path("../config/feature_categories.yml", __dir__)

    # List of feature categories which are not defined in config/feature_categories.yml
    # https://docs.gitlab.com/ee/development/feature_categorization/#tooling-feature-category
    # https://docs.gitlab.com/ee/development/feature_categorization/#shared-feature-category
    CUSTOM_CATEGORIES = %w[
      tooling
      shared
    ].to_set.freeze

    def self.available
      @available ||= YAML.load_file(CONFIG_PATH).to_set
    end

    def self.available_with_custom
      @available_with_custom ||= available.union(CUSTOM_CATEGORIES)
    end

    # Used by RuboCop to invalidate its cache if the contents of
    # config/feature_categories.yml changes.
    # Define a method called `external_dependency_checksum` and call
    # this method to use it.
    def self.config_checksum
      @config_checksum ||= Digest::SHA256.file(CONFIG_PATH).hexdigest
    end

    attr_reader :categories

    def initialize(categories)
      @categories = categories
    end

    def check(value_node:, document_link:)
      return yield(MSG_SYMBOL) unless value_node.sym_type?
      return if categories.include?(value_node.value.to_s)

      message = format(
        MSG,
        msg_suggestion: suggestion_message(value_node),
        document_link: document_link)

      yield(message)
    end

    def suggestion_message(value_node)
      spell = DidYouMean::SpellChecker.new(dictionary: categories)

      suggestions = spell.correct(value_node.value)
      return if suggestions.none?

      format(MSG_DID_YOU_MEAN, suggestion: suggestions.first)
    end
  end
end
