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

  # Due date = first Needs Attention day (end of Warning). Prefer cache
  # needs_attention_at. While in Grey Grace, due is at least the day after
  # grace_until_at so captions stay on the "Next due" path until grace ends.
  def due_on_for(item)
    return nil if item.blank?

    inputs = item.inputs || {}
    cached_needs_attention = parse_date(inputs["needs_attention_at"])
    grace_until = parse_date(inputs["grace_until_at"])
    in_grace = clarity_check_in_grace?(inputs)

    if in_grace && grace_until
      grace_due = grace_until + 1.day
      return [cached_needs_attention, grace_due].compact.max
    end

    # Indefinite assignment grace (no >0% tenure yet): not due.
    return nil if in_grace && indefinite_assignment_grace?(inputs)

    return cached_needs_attention if cached_needs_attention

    last_event = parse_date(inputs["last_event_at"])
    if last_event
      return last_event + EngagementHealth::Thresholds.required_clarity_needs_attention_at_days_from(inputs: inputs)
    end

    tenure_start = parse_date(inputs["tenure_chain_started_at"])
    if tenure_start
      return tenure_start + EngagementHealth::Thresholds.required_clarity_needs_attention_at_days_from(inputs: inputs)
    end

    nil
  end

  def clarity_check_in_grace?(inputs)
    inputs ||= {}
    ActiveModel::Type::Boolean.new.cast(
      inputs["clarity_check_in_grace"].nil? ? inputs["new_assignment_grace"] : inputs["clarity_check_in_grace"]
    )
  end

  def indefinite_assignment_grace?(inputs)
    inputs ||= {}
    ActiveModel::Type::Boolean.new.cast(inputs["indefinite_assignment_grace"])
  end

  # Earliest due among required/active clarity items. Never-finalized items
  # without a derivable due date sort first (most urgent), except indefinite
  # Grey Grace (no energy yet), which sorts last.
  def earliest_due_item(records)
    items = items_for(records)
    return nil if items.empty?

    items.min_by do |item|
      inputs = item.inputs || {}
      due = due_on_for(item)
      urgency =
        if due.nil? && clarity_check_in_grace?(inputs) && indefinite_assignment_grace?(inputs)
          2
        elsif due.nil?
          0
        else
          1
        end
      [urgency, due || Date.new(1), item.entity_type.to_s, item.entity_id.to_i]
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
