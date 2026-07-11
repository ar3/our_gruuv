# frozen_string_literal: true

# Gruuv Health lookups for Observations Health (OGO Given + Received category rollups).
module ObservationsHealthEngagementHealthSupport
  CATEGORIES = [
    EngagementHealth::CATEGORY_OGO_GIVEN,
    EngagementHealth::CATEGORY_OGO_RECEIVED
  ].freeze

  module_function

  def records_by_teammate_id(organization:, teammate_ids:)
    return {} if teammate_ids.blank?

    EngagementHealthStatus
      .where(organization: organization, teammate_id: teammate_ids, category: CATEGORIES)
      .group_by(&:teammate_id)
  end

  def category_rollup(records, category)
    Array(records).find { |record| record.level == "category" && record.category == category }
  end

  def given_status(records)
    category_rollup(records, EngagementHealth::CATEGORY_OGO_GIVEN)&.status
  end

  def received_status(records)
    category_rollup(records, EngagementHealth::CATEGORY_OGO_RECEIVED)&.status
  end

  def overall_status(records)
    EngagementHealth.worst_status(
      [
        given_status(records) || EngagementHealth::NEEDS_ATTENTION,
        received_status(records) || EngagementHealth::NEEDS_ATTENTION
      ]
    )
  end

  def section_payload(records, category:, observations_count: nil)
    rollup = category_rollup(records, category)
    inputs = rollup&.inputs || {}
    last_published_at = inputs["last_event_at"]

    {
      "status" => rollup&.status || EngagementHealth::NEEDS_ATTENTION,
      "last_published_at" => last_published_at,
      "observations_count" => observations_count.to_i,
      "never" => inputs.key?("never") ? inputs["never"] : last_published_at.blank?,
      "days_since_last_event" => inputs["days_since_last_event"]
    }
  end

  def computed_at_for(records)
    Array(records).map(&:computed_at).compact.max
  end
end
