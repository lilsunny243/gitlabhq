# frozen_string_literal: true

module Ci
  class BuildNeed < Ci::ApplicationRecord
    include Ci::Partitionable
    include IgnorableColumns
    include SafelyChangeColumnDefault
    include BulkInsertSafe

    MAX_JOB_NAME_LENGTH = 128

    columns_changing_default :partition_id

    belongs_to :build, class_name: "Ci::Processable", foreign_key: :build_id, inverse_of: :needs

    partitionable scope: :build

    validates :build, presence: true
    validates :name, presence: true, length: { maximum: MAX_JOB_NAME_LENGTH }
    validates :optional, inclusion: { in: [true, false] }

    scope :scoped_build, -> { where("#{Ci::Build.quoted_table_name}.id = #{quoted_table_name}.build_id") }
    scope :artifacts, -> { where(artifacts: true) }
  end
end
