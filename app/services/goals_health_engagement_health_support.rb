# frozen_string_literal: true

# Gruuv Health lookups for Goals Health (Goal Confidence category rollups + per-goal items).
module GoalsHealthEngagementHealthSupport
  CATEGORY = EngagementHealth::CATEGORY_GOAL_CONFIDENCE

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

  # Never started/completed (or no in-scope goals) → Needs Attention. Missing cache → same.
  def category_status(records)
    category_rollup(records)&.status || EngagementHealth::NEEDS_ATTENTION
  end

  def items_for(records)
    Array(records).select { |record| record.level == "item" && record.category == CATEGORY }
  end

  def items_by_goal_id(records)
    items_for(records).each_with_object({}) do |record, memo|
      next if record.entity_id.blank?

      memo[record.entity_id.to_i] = record
    end
  end

  def spotlight_symbol(status)
    case status.to_s
    when EngagementHealth::HEALTHY then :healthy
    when EngagementHealth::WARNING then :ok
    else :concerning
    end
  end

  def computed_at_for(records)
    Array(records).map(&:computed_at).compact.max
  end
end
