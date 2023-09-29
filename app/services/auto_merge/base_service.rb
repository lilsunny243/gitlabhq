# frozen_string_literal: true

module AutoMerge
  class BaseService < ::BaseService
    include Gitlab::Utils::StrongMemoize
    include MergeRequests::AssignsMergeParams

    def execute(merge_request)
      ApplicationRecord.transaction do
        register_auto_merge_parameters!(merge_request)
        yield if block_given?
      end

      notify(merge_request)
      AutoMergeProcessWorker.perform_async(merge_request.id)

      strategy.to_sym
    rescue StandardError => e
      track_exception(e, merge_request)
      :failed
    end

    def process(_)
      raise NotImplementedError
    end

    def update(merge_request)
      assign_allowed_merge_params(merge_request, params.merge(auto_merge_strategy: strategy))

      return :failed unless merge_request.save

      strategy.to_sym
    end

    def cancel(merge_request)
      ApplicationRecord.transaction do
        clear_auto_merge_parameters!(merge_request)
        yield if block_given?
      end

      success
    rescue StandardError => e
      track_exception(e, merge_request)
      error("Can't cancel the automatic merge", 406)
    end

    def abort(merge_request, reason)
      ApplicationRecord.transaction do
        clear_auto_merge_parameters!(merge_request)
        yield if block_given?
      end

      success
    rescue StandardError => e
      track_exception(e, merge_request)
      error("Can't abort the automatic merge", 406)
    end

    def available_for?(merge_request)
      strong_memoize("available_for_#{merge_request.id}") do
        merge_request.can_be_merged_by?(current_user) &&
          merge_request.open? &&
          !merge_request.broken? &&
          (skip_draft_check(merge_request) || !merge_request.draft?) &&
          merge_request.mergeable_discussions_state? &&
          !merge_request.merge_blocked_by_other_mrs? &&
          yield
      end
    end

    private

    # Overridden in child classes
    def notify(merge_request)
    end

    def strategy
      strong_memoize(:strategy) do
        self.class.name.demodulize.remove('Service').underscore
      end
    end

    def register_auto_merge_parameters!(merge_request)
      assign_allowed_merge_params(merge_request, params.merge(auto_merge_strategy: strategy))
      merge_request.auto_merge_enabled = true
      merge_request.merge_user = current_user
      merge_request.save!
    end

    def clear_auto_merge_parameters!(merge_request)
      merge_request.auto_merge_enabled = false
      merge_request.merge_user = nil

      merge_request.merge_params&.except!(*clearable_auto_merge_parameters)

      merge_request.save!
    end

    # Overridden in EE child classes
    def clearable_auto_merge_parameters
      %w[
        should_remove_source_branch
        commit_message
        squash_commit_message
        auto_merge_strategy
      ]
    end

    def track_exception(error, merge_request)
      Gitlab::ErrorTracking.track_exception(error, merge_request_id: merge_request&.id)
    end

    # Will skip the draft check or not when checking if strategy is available
    def skip_draft_check(merge_request)
      false
    end
  end
end
