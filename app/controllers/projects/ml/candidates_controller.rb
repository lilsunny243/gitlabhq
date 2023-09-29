# frozen_string_literal: true

module Projects
  module Ml
    class CandidatesController < ApplicationController
      before_action :set_candidate
      before_action :check_read, only: [:show]
      before_action :check_write, only: [:destroy]

      feature_category :mlops

      def show
        @include_ci_info = @candidate.from_ci? && can?(current_user, :read_build, @candidate.ci_build)
      end

      def destroy
        @experiment = @candidate.experiment
        @candidate.destroy!

        redirect_to project_ml_experiment_path(@project, @experiment.iid),
          status: :found,
          notice: s_("MlExperimentTracking|Candidate removed")
      end

      private

      def set_candidate
        @candidate = ::Ml::Candidate.with_project_id_and_iid(@project.id, params['iid'])

        render_404 unless @candidate.present?
      end

      def check_read
        render_404 unless can?(current_user, :read_model_experiments, @project)
      end

      def check_write
        render_404 unless can?(current_user, :write_model_experiments, @project)
      end
    end
  end
end
