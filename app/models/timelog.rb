# frozen_string_literal: true

class Timelog < ApplicationRecord
  include Importable
  include IgnorableColumns
  include Sortable

  ignore_column :note_id_convert_to_bigint, remove_with: '16.2', remove_after: '2023-07-22'

  before_save :set_project

  validates :time_spent, :user, presence: true
  validates :summary, length: { maximum: 255 }
  validate :issuable_id_is_present, unless: :importing?

  belongs_to :issue, touch: true
  belongs_to :merge_request, touch: true
  belongs_to :project
  belongs_to :user
  belongs_to :note

  scope :in_group, -> (group) do
    joins(:project).where(projects: { namespace: group.self_and_descendants })
  end

  scope :in_project, -> (project) do
    where(project: project)
  end

  scope :for_user, -> (user) do
    where(user: user)
  end

  scope :at_or_after, -> (start_time) do
    where('spent_at >= ?', start_time)
  end

  scope :at_or_before, -> (end_time) do
    where('spent_at <= ?', end_time)
  end

  scope :order_scope_asc, ->(field) { order(arel_table[field].asc.nulls_last) }
  scope :order_scope_desc, ->(field) { order(arel_table[field].desc.nulls_last) }

  def issuable
    issue || merge_request
  end

  def self.sort_by_field(field)
    case field.to_s
    when 'spent_at_asc' then order_scope_asc(:spent_at)
    when 'spent_at_desc' then order_scope_desc(:spent_at)
    when 'time_spent_asc' then order_scope_asc(:time_spent)
    when 'time_spent_desc' then order_scope_desc(:time_spent)
    else order_by(field)
    end
  end

  private

  def issuable_id_is_present
    if issue_id && merge_request_id
      errors.add(:base, _('Only Issue ID or merge request ID is required'))
    elsif issuable.nil?
      errors.add(:base, _('Issue or merge request ID is required'))
    end
  end

  def set_project
    self.project_id = issuable.project_id
  end

  # Rails5 defaults to :touch_later, overwrite for normal touch
  def belongs_to_touch_method
    :touch
  end
end
