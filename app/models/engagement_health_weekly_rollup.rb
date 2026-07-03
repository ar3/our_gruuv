# frozen_string_literal: true

# Category-level Gruuv Health status as of each completed Sunday. Powers
# historical scorecard weeks and insights trends. The live engagement_health_statuses
# table remains the current-state cache (including the in-progress week).
class EngagementHealthWeeklyRollup < ApplicationRecord
  belongs_to :teammate, class_name: "CompanyTeammate"
  belongs_to :organization, class_name: "Organization"

  validates :week_ending_on, presence: true
  validates :category, inclusion: { in: EngagementHealth::CATEGORIES }
  validates :status, inclusion: { in: EngagementHealth::STATUSES }
  validates :computed_at, presence: true
end
