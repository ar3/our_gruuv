# frozen_string_literal: true

# Shared Gruuv Health lookups for the Check-ins Health dashboard (Required Clarity only).
module CheckInsHealthEngagementHealthSupport
  CATEGORY = EngagementHealth::CATEGORY_REQUIRED_CLARITY

  module_function

  def records_by_teammate_id(organization:, teammate_ids:)
    return {} if teammate_ids.blank?

    EngagementHealthStatus
      .where(organization: organization, teammate_id: teammate_ids, category: CATEGORY)
      .group_by(&:teammate_id)
  end

  def items_for(records, entity_type: nil)
    items = Array(records).select { |record| record.level == "item" && record.category == CATEGORY }
    return items if entity_type.blank?

    items.select { |record| record.entity_type == entity_type }
  end

  def category_rollup(records)
    Array(records).find { |record| record.level == "category" && record.category == CATEGORY }
  end

  def clarity_rollup_status(records)
    category_rollup(records)&.status
  end

  def status_counts(items)
    EngagementHealth::STATUSES.index_with(0).tap do |counts|
      Array(items).each do |item|
        counts[item.status] += 1 if counts.key?(item.status)
      end
    end
  end

  def worst_item(records)
    items = items_for(records)
    return nil if items.empty?

    items.min_by { |item| EngagementHealth.status_severity_rank(item.status) }
  end

  def all_clear?(records)
    clarity_rollup_status(records) == EngagementHealth::HEALTHY
  end

  def computed_at_for(records)
    Array(records).map(&:computed_at).compact.max
  end

  # Due date at end of Warning / Needs Attention boundary:
  # last finalized + REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS (90).
  # Never-finalized assignments with tenure use tenure start + the same window.
  def due_on_for(item)
    return nil if item.blank?

    inputs = item.inputs || {}
    last_event = parse_date(inputs["last_event_at"])
    if last_event
      return last_event + EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS
    end

    tenure_start = parse_date(inputs["tenure_chain_started_at"])
    if tenure_start
      return tenure_start + EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS
    end

    nil
  end

  # Earliest due among required/active clarity items. Never-finalized items
  # without a derivable due date sort first (most urgent).
  def earliest_due_item(records)
    items = items_for(records)
    return nil if items.empty?

    items.min_by do |item|
      due = due_on_for(item)
      [due.nil? ? 0 : 1, due || Date.new(1), item.entity_type.to_s, item.entity_id.to_i]
    end
  end

  def parse_date(value)
    return nil if value.blank?
    return value.to_date if value.respond_to?(:to_date)

    Time.zone.parse(value.to_s)&.to_date
  rescue ArgumentError, TypeError
    nil
  end
  private_class_method :parse_date
end
