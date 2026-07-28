# frozen_string_literal: true

# Gruuv Health lookups for Milestones Health (Milestones category rollups + ability items).
module MilestonesHealthEngagementHealthSupport
  CATEGORY = EngagementHealth::CATEGORY_MILESTONES

  REASON_COPY = {
    "earned_required_milestone" => "Required milestone earned",
    "active_goal_attached" => "Active goal attached",
    "earlier_milestone_earned" => "Earlier milestone only",
    "draft_goal_attached" => "Draft goal only",
    "no_milestone_and_no_goal" => "No milestone and no goal"
  }.freeze

  module_function

  def records_by_teammate_id(organization:, teammate_ids:)
    return {} if teammate_ids.blank?

    EngagementHealthStatus
      .where(organization: organization, teammate_id: teammate_ids, category: CATEGORY)
      .group_by(&:teammate_id)
  end

  def category_rollup(records)
    Array(records).find { |record| record.level == "category" && record.category == CATEGORY }
  end

  # Missing cache → Needs Attention. Computed empty required set is vacuously Healthy.
  def category_status(records)
    category_rollup(records)&.status || EngagementHealth::NEEDS_ATTENTION
  end

  def items_for(records)
    Array(records).select { |record| record.level == "item" && record.category == CATEGORY }
  end

  def status_counts(items)
    EngagementHealth::STATUSES.index_with(0).tap do |counts|
      Array(items).each do |item|
        counts[item.status] += 1 if counts.key?(item.status)
      end
    end
  end

  def spotlight_symbol(status)
    case status.to_s
    when EngagementHealth::HEALTHY then :healthy
    when EngagementHealth::WARNING then :ok
    else :concerning
    end
  end

  def reason_copy(reason)
    REASON_COPY.fetch(reason.to_s) { reason.to_s.humanize }
  end

  def computed_at_for(records)
    Array(records).map(&:computed_at).compact.max
  end
end
