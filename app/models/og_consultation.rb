# frozen_string_literal: true

class OgConsultation < ApplicationRecord
  KINDS = %w[
    ability_clarity
    assignment_clarity
    position_clarity
    teammate_growth
    ogo_search_transcript
    ogo_search_slack
    ogo_search_consult
  ].freeze

  STATUSES = %w[pending processing completed failed].freeze

  KIND_ABILITY_CLARITY = 'ability_clarity'
  KIND_ASSIGNMENT_CLARITY = 'assignment_clarity'
  KIND_POSITION_CLARITY = 'position_clarity'
  KIND_TEAMMATE_GROWTH = 'teammate_growth'
  KIND_OGO_SEARCH_TRANSCRIPT = 'ogo_search_transcript'
  KIND_OGO_SEARCH_SLACK = 'ogo_search_slack'
  KIND_OGO_SEARCH_CONSULT = 'ogo_search_consult'

  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :organization, class_name: 'Organization'
  belongs_to :triggered_by_teammate, class_name: 'CompanyTeammate', optional: true
  belongs_to :result, polymorphic: true, optional: true

  has_many :llm_invocations, as: :parent, dependent: :nullify

  has_one :ability_clarity_result, dependent: :destroy
  has_one :assignment_clarity_result, dependent: :destroy
  has_one :position_clarity_result, dependent: :destroy
  has_one :teammate_growth_result, dependent: :destroy
  has_one :ogo_search_result, dependent: :destroy

  validates :kind, presence: true, inclusion: { in: ->(_) { OgConsultations::Kinds.kinds } }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :units_total, :units_completed,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :billable, -> { where(billable: true) }
  scope :completed, -> { where(status: 'completed') }
  scope :for_kind, ->(kind) { where(kind: kind) }
  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  def self.latest_for(subject:, kind:)
    where(subject: subject, kind: kind).latest_first.first
  end

  def terminal?
    status.in?(%w[completed failed])
  end

  def in_flight?
    status.in?(%w[pending processing])
  end

  def mark_processing!
    update!(
      status: 'processing',
      started_at: started_at || Time.current
    )
  end

  def increment_units_completed!
    increment!(:units_completed)
  end

  # Convenience readers for existing Consult OG views (delegate to kind-specific result).
  def output_text
    result&.try(:output_text)
  end

  def clarity_rating
    result&.try(:clarity_rating)
  end

  def clarity_score
    result&.try(:clarity_score)
  end

  def clarity_recommendations
    result&.try(:clarity_recommendations) || []
  end

  def consult_focus
    result&.try(:consult_focus)
  end

  def assignment_clarity_recommendation_acceptances
    return AssignmentClarityRecommendationAcceptance.none unless result.is_a?(AssignmentClarityResult)

    result.assignment_clarity_recommendation_acceptances
  end
end
