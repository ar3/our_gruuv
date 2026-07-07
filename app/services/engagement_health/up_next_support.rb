# frozen_string_literal: true

module EngagementHealth
  # Shared Up Next list ordering and per-perspective action counts from Gruuv Health
  # Required Clarity item rows (status + workflow snapshot inputs).
  module UpNextSupport
    TYPE_ORDER = { aspiration: 0, assignment: 1, position: 2 }.freeze

    module_function

    def index_items_by_key(records)
      indexed = ClarityMetrics.clarity_items(records).index_by { |item| item_key(item) }
      position_item = ClarityMetrics.clarity_items(records).find { |item| item.entity_type == "Position" }
      indexed["position:none"] = position_item if position_item
      indexed
    end

    def find_item(eh_by_key, item)
      eh_by_key[item_key(item)] || (item[:type] == :position ? eh_by_key["position:none"] : nil)
    end

    def item_key(source)
      if source.respond_to?(:entity_type)
        "#{entity_type_to_sym(source.entity_type)}:#{source.entity_id || 'none'}"
      else
        "#{source[:type]}:#{source[:id] || 'none'}"
      end
    end

    def entity_type_to_sym(entity_type)
      case entity_type.to_s
      when "Aspiration" then :aspiration
      when "Assignment" then :assignment
      when "Position" then :position
      end
    end

    def actions_needed_count(eh_item, manager_perspective:)
      return 0 unless eh_item
      return 0 if eh_item.status == HEALTHY

      inputs = eh_item.inputs
      if inputs["open_check_in_present"]
        count = 0
        if manager_perspective
          count += 1 unless inputs["open_manager_completed"]
          count += 1 if inputs["open_ready_for_finalization"]
        else
          count += 1 unless inputs["open_employee_completed"]
        end
        count
      else
        1
      end
    end

    def actions_total_count(eh_item, manager_perspective:)
      return 0 unless eh_item

      manager_perspective ? 2 : 1
    end

    def sort_items_for_perspective(items, eh_by_key:, manager_perspective:)
      items.sort_by do |item|
        eh_item = find_item(eh_by_key, item)
        needed = actions_needed_count(eh_item, manager_perspective: manager_perspective)
        severity = eh_item ? EngagementHealth.status_severity_rank(eh_item.status) : STATUSES.size
        type_rank = TYPE_ORDER[item[:type]] || 99
        name = item[:name].to_s.downcase

        [-needed, severity, type_rank, name]
      end
    end

    def status_explainer(eh_item:, index:, ordered_items:, manager_perspective:, eh_by_key:)
      return "Gruuv Health has not been calculated for this item yet." unless eh_item

      label = STATUS_LABELS.fetch(eh_item.status)
      meaning = status_meaning_phrase(eh_item)
      rank = rank_reason(
        index: index,
        ordered_items: ordered_items,
        manager_perspective: manager_perspective,
        eh_by_key: eh_by_key
      )
      "Gruuv Health is #{label} (#{meaning}). #{rank}"
    end

    def actions_line(count:, person_name:, eh_item:)
      name = person_name.presence || "They"
      return "No Gruuv Health actions needed from #{name}" if count.zero?

      urgency = eh_item&.status == NEEDS_ATTENTION ? "required" : "encouraged"
      action_word = count == 1 ? "action" : "actions"
      "#{count} #{action_word} #{urgency} from #{name}"
    end

    def workflow_completion(eh_item:, latest_open:)
      if latest_open
        {
          employee_done: latest_open.employee_completed_at.present?,
          manager_done: latest_open.manager_completed_at.present?,
          ready_for_joint_review: latest_open.ready_for_finalization?
        }
      elsif eh_item
        inputs = eh_item.inputs
        {
          employee_done: inputs["open_employee_completed"] == true,
          manager_done: inputs["open_manager_completed"] == true,
          ready_for_joint_review: inputs["open_ready_for_finalization"] == true
        }
      else
        {
          employee_done: false,
          manager_done: false,
          ready_for_joint_review: false
        }
      end
    end

    def status_meaning_phrase(eh_item)
      days = eh_item.inputs["days_since_last_event"]
      case eh_item.status
      when HEALTHY
        if days.nil?
          "recently finalized"
        else
          "finalized within #{Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS} days"
        end
      when WARNING
        "finalized #{Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS + 1}–" \
          "#{Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS - 1} days ago"
      when NEEDS_ATTENTION
        if eh_item.inputs["never"]
          "never finalized"
        else
          "finalized #{Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS}+ days ago"
        end
      else
        eh_item.status.to_s.humanize.downcase
      end
    end

    def rank_reason(index:, ordered_items:, manager_perspective:, eh_by_key:)
      item = ordered_items[index]
      eh_item = find_item(eh_by_key, item)
      needed = actions_needed_count(eh_item, manager_perspective: manager_perspective)

      if index.zero? && needed.positive?
        return "Ranked first because this item still needs your action."
      end
      return "Ranked first among remaining items." if index.zero?

      previous = ordered_items[index - 1]
      previous_eh_item = find_item(eh_by_key, previous)
      previous_needed = actions_needed_count(
        previous_eh_item,
        manager_perspective: manager_perspective
      )
      if needed.positive? && previous_needed.zero?
        return "Listed after items that no longer need your action."
      end
      if needed.positive? && previous_needed.positive?
        prev_severity = EngagementHealth.status_severity_rank(previous_eh_item&.status)
        curr_severity = EngagementHealth.status_severity_rank(eh_item&.status)
        if curr_severity > prev_severity
          return "Listed after more urgent Gruuv Health items."
        end
      end

      "Ordered by Gruuv Health urgency, item type, and name."
    end
  end
end
