# frozen_string_literal: true

class MaapAgentRun < ApplicationRecord
  AGENT_KIND_ABILITY_CLARITY = 'ability_clarity'
  AGENT_KIND_ASSIGNMENT_CLARITY = 'assignment_clarity'
  AGENT_KIND_POSITION_CLARITY = 'position_clarity'
  AGENT_KIND_TEAMMATE_GROWTH = 'teammate_growth'

  STATUSES = %w[pending processing completed failed].freeze
  CLARITY_RATINGS = %w[green yellow red].freeze

  belongs_to :subject, polymorphic: true
  belongs_to :triggered_by_teammate, class_name: 'CompanyTeammate', optional: true
  has_paper_trail meta: {
    completed_event: ->(record) { record.completed_event_marker? },
    completed_triggered_by_teammate_id: ->(record) {
      record.completed_event_marker? ? record.triggered_by_teammate_id : nil
    },
    agent_kind: ->(record) { record.agent_kind }
  }

  validates :agent_kind, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :clarity_rating, inclusion: { in: CLARITY_RATINGS }, allow_nil: true
  validates :clarity_score,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true

  scope :ability_clarity, -> { where(agent_kind: AGENT_KIND_ABILITY_CLARITY) }
  scope :assignment_clarity, -> { where(agent_kind: AGENT_KIND_ASSIGNMENT_CLARITY) }
  scope :position_clarity, -> { where(agent_kind: AGENT_KIND_POSITION_CLARITY) }
  scope :teammate_growth, -> { where(agent_kind: AGENT_KIND_TEAMMATE_GROWTH) }

  def terminal?
    status.in?(%w[completed failed])
  end

  def completed_event_marker?
    status == 'completed' && saved_change_to_status?
  end
end
