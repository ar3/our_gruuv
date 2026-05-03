# frozen_string_literal: true

class MaapAgentRun < ApplicationRecord
  AGENT_KIND_ABILITY_CLARITY = 'ability_clarity'
  AGENT_KIND_ASSIGNMENT_CLARITY = 'assignment_clarity'
  AGENT_KIND_POSITION_CLARITY = 'position_clarity'

  STATUSES = %w[pending processing completed failed].freeze
  CLARITY_RATINGS = %w[green yellow red].freeze

  belongs_to :subject, polymorphic: true
  belongs_to :triggered_by_teammate, class_name: 'CompanyTeammate', optional: true

  validates :agent_kind, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :clarity_rating, inclusion: { in: CLARITY_RATINGS }, allow_nil: true

  scope :ability_clarity, -> { where(agent_kind: AGENT_KIND_ABILITY_CLARITY) }
  scope :assignment_clarity, -> { where(agent_kind: AGENT_KIND_ASSIGNMENT_CLARITY) }
  scope :position_clarity, -> { where(agent_kind: AGENT_KIND_POSITION_CLARITY) }

  def terminal?
    status.in?(%w[completed failed])
  end
end
