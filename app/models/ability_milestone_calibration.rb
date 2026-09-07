# frozen_string_literal: true

class AbilityMilestoneCalibration < ApplicationRecord
  belongs_to :company_teammate, class_name: 'CompanyTeammate', foreign_key: 'teammate_id'
  alias_method :teammate, :company_teammate
  alias_method :teammate=, :company_teammate=

  belongs_to :manager_completed_by_teammate, class_name: 'CompanyTeammate', optional: true
  has_many :items, class_name: 'AbilityMilestoneCalibrationItem', dependent: :destroy,
                   inverse_of: :ability_milestone_calibration

  validates :company_teammate, presence: true
  validates :teammate_id, uniqueness: true

  # Any ability where both sides have rated and award is still pending.
  def ready_for_review?
    items.ready_for_review.exists?
  end

  def pending_award_items
    items.ready_for_review.ordered_by_ability_name
  end

  # Open abilities still being rated / awaiting award.
  def rateable_items
    items.where(awarded_at: nil).ordered_by_ability_name
  end

  # Awarded rows that still have both proposals — collapsed history on the calibration page.
  def history_items
    items.calibration_history.order(awarded_at: :desc)
  end
end
