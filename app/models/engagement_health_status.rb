# frozen_string_literal: true

# One cached engagement-health rating: either a single item (a goal, a required
# check-in item, an ability, or the OGO signal) or a category rollup.
# All threshold/rollup logic lives in EngagementHealth::Calculator — this model
# only stores results plus the inputs used, so ratings can be hand-verified.
class EngagementHealthStatus < ApplicationRecord
  belongs_to :teammate, class_name: "CompanyTeammate"
  belongs_to :organization, class_name: "Organization"

  LEVELS = %w[item category].freeze

  validates :level, inclusion: { in: LEVELS }
  validates :category, inclusion: { in: EngagementHealth::CATEGORIES }
  validates :status, inclusion: { in: EngagementHealth::STATUSES }
  validates :computed_at, presence: true

  scope :items, -> { where(level: "item") }
  scope :category_rollups, -> { where(level: "category") }
  scope :for_category, ->(category) { where(category: category) }

  # Stable identity for cache-vs-fresh comparison on the debug page.
  def row_key
    EngagementHealth.row_key(category: category, level: level, entity_type: entity_type, entity_id: entity_id)
  end

  def healthy? = status == EngagementHealth::HEALTHY
  def warning? = status == EngagementHealth::WARNING
  def needs_attention? = status == EngagementHealth::NEEDS_ATTENTION
end
