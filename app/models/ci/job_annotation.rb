# frozen_string_literal: true

module Ci
  class JobAnnotation < Ci::ApplicationRecord
    include Ci::Partitionable
    include BulkInsertSafe

    self.table_name = :p_ci_job_annotations
    self.primary_key = :id

    belongs_to :job, class_name: 'Ci::Build', inverse_of: :job_annotations

    partitionable scope: :job, partitioned: true

    validates :data, json_schema: { filename: 'ci_job_annotation_data' }
    validates :name, presence: true,
      length: { maximum: 255 }
  end
end
