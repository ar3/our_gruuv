# frozen_string_literal: true

module EngagementHealth
  # Action-slot math for Required Clarity: 3 actions per item (employee, manager, finalize together).
  # Completed slots always count toward "healthy progress"; incomplete slots count toward the item's
  # Warning or Needs Attention bucket. Healthy items contribute all 3 slots to Healthy.
  module ClarityActionMetrics
    ACTIONS_PER_ITEM = 3

    SlotBreakdown = Struct.new(
      :healthy_slots,
      :warning_slots,
      :needs_attention_slots,
      :total_slots,
      :healthy_percentage,
      :warning_percentage,
      :needs_attention_percentage,
      keyword_init: true
    ) do
      def ok_percentage
        healthy_percentage.to_f + warning_percentage.to_f
      end
    end

    SpotlightStats = Struct.new(
      :total_action_slots,
      :healthy_action_slots,
      :warning_action_slots,
      :needs_attention_action_slots,
      :actions_to_full_maap,
      keyword_init: true
    )

    PopoverRow = Struct.new(
      :name,
      :status,
      :employee_done,
      :manager_done,
      :together_done,
      keyword_init: true
    )

    module_function

    def for_records(records)
      items = ClarityMetrics.clarity_items(records)
      breakdown_for_items(items)
    end

    def breakdown_for_items(items)
      items = Array(items)
      totals = empty_slot_totals

      items.each do |item|
        merge_slot_totals!(totals, slot_counts_for_item(item))
      end

      build_breakdown(totals)
    end

    def popover_rows(records)
      ClarityMetrics.clarity_items(records)
        .select { |item| item.status.in?([WARNING, NEEDS_ATTENTION]) }
        .sort_by { |item| [EngagementHealth.status_severity_rank(item.status), item.inputs["name"].to_s.downcase] }
        .map { |item| build_popover_row(item) }
    end

    def spotlight_stats(organization:, teammate_ids:)
      return empty_spotlight_stats if teammate_ids.blank?

      items = EngagementHealthStatus.where(
        organization: organization,
        teammate_id: teammate_ids,
        category: CATEGORY_REQUIRED_CLARITY,
        level: "item"
      ).to_a

      aggregate_spotlight_stats(items)
    end

    def action_slots_completed(item)
      return { employee: true, manager: true, together: true } if item.status == HEALTHY

      inputs = item.inputs
      if inputs["open_check_in_present"]
        {
          employee: inputs["open_employee_completed"] == true,
          manager: inputs["open_manager_completed"] == true,
          together: false
        }
      else
        {
          employee: false,
          manager: false,
          together: false
        }
      end
    end

    def slot_counts_for_item(item)
      return { healthy_slots: ACTIONS_PER_ITEM, warning_slots: 0, needs_attention_slots: 0 } if item.status == HEALTHY

      slots = action_slots_completed(item)
      completed = [slots[:employee], slots[:manager], slots[:together]].count(true)
      incomplete = ACTIONS_PER_ITEM - completed

      if item.status == WARNING
        { healthy_slots: completed, warning_slots: incomplete, needs_attention_slots: 0 }
      else
        { healthy_slots: completed, warning_slots: 0, needs_attention_slots: incomplete }
      end
    end

    def empty_slot_totals
      { healthy_slots: 0, warning_slots: 0, needs_attention_slots: 0 }
    end

    def merge_slot_totals!(totals, counts)
      totals[:healthy_slots] += counts[:healthy_slots]
      totals[:warning_slots] += counts[:warning_slots]
      totals[:needs_attention_slots] += counts[:needs_attention_slots]
    end

    def build_breakdown(totals)
      total_slots = totals.values.sum
      if total_slots.zero?
        return SlotBreakdown.new(
          healthy_slots: 0,
          warning_slots: 0,
          needs_attention_slots: 0,
          total_slots: 0,
          healthy_percentage: 0.0,
          warning_percentage: 0.0,
          needs_attention_percentage: 0.0
        )
      end

      SlotBreakdown.new(
        healthy_slots: totals[:healthy_slots],
        warning_slots: totals[:warning_slots],
        needs_attention_slots: totals[:needs_attention_slots],
        total_slots: total_slots,
        healthy_percentage: percentage(totals[:healthy_slots], total_slots),
        warning_percentage: percentage(totals[:warning_slots], total_slots),
        needs_attention_percentage: percentage(totals[:needs_attention_slots], total_slots)
      )
    end

    def aggregate_spotlight_stats(items)
      totals = empty_slot_totals

      items.each do |item|
        merge_slot_totals!(totals, slot_counts_for_item(item))
      end

      SpotlightStats.new(
        total_action_slots: totals.values.sum,
        healthy_action_slots: totals[:healthy_slots],
        warning_action_slots: totals[:warning_slots],
        needs_attention_action_slots: totals[:needs_attention_slots],
        actions_to_full_maap: totals[:warning_slots] + totals[:needs_attention_slots]
      )
    end

    def empty_spotlight_stats
      SpotlightStats.new(
        total_action_slots: 0,
        healthy_action_slots: 0,
        warning_action_slots: 0,
        needs_attention_action_slots: 0,
        actions_to_full_maap: 0
      )
    end

    def build_popover_row(item)
      slots = action_slots_completed(item)
      PopoverRow.new(
        name: item.inputs["name"].to_s,
        status: item.status,
        employee_done: slots[:employee],
        manager_done: slots[:manager],
        together_done: slots[:together]
      )
    end

    def percentage(numerator, denominator)
      (numerator.to_f / denominator * 100).round(1)
    end
  end
end
