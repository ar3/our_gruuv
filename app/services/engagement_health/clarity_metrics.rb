# frozen_string_literal: true

module EngagementHealth
  # Required-clarity rollups for dashboards, managers view, CSV exports, and
  # legacy completion-rate call sites migrated off check_in_health_caches.
  module ClarityMetrics
    module_function

    def records_for_teammate(organization:, teammate_id:)
      return [] if teammate_id.blank?

      EngagementHealthStatus
        .where(organization: organization, teammate_id: teammate_id, category: CATEGORY_REQUIRED_CLARITY)
        .to_a
    end

    def records_by_teammate_id(organization:, teammate_ids:)
      CheckInsHealthEngagementHealthSupport.records_by_teammate_id(
        organization: organization,
        teammate_ids: teammate_ids
      )
    end

    def clarity_items(records)
      CheckInsHealthEngagementHealthSupport.items_for(records)
    end

    def items_for_entity_type(records, entity_type:)
      CheckInsHealthEngagementHealthSupport.items_for(records, entity_type: entity_type)
    end

    def healthy_percentage(items)
      items = Array(items)
      return 0.0 if items.empty?

      healthy = items.count { |item| item.status == HEALTHY }
      (healthy.to_f / items.size * 100).round(1)
    end

    def ok_percentage(items)
      items = Array(items)
      return 0.0 if items.empty?

      ok = items.count { |item| item.status.in?([HEALTHY, AT_RISK]) }
      (ok.to_f / items.size * 100).round(1)
    end

    def breakdown(records)
      items = clarity_items(records)
      return nil if items.empty?

      by_type = items.group_by(&:entity_type)
      position_items = by_type["Position"] || []
      assignment_items = by_type["Assignment"] || []
      aspiration_items = by_type["Aspiration"] || []

      {
        completion_rate: healthy_percentage(items),
        position_pct: healthy_percentage(position_items).round(0),
        assignments_pct: healthy_percentage(assignment_items).round(0),
        aspirations_pct: healthy_percentage(aspiration_items).round(0)
      }
    end

    def fully_clear?(records)
      items = clarity_items(records)
      items.present? && items.all?(&:healthy?)
    end

    def popover_table_data(records)
      by_type = clarity_items(records).group_by(&:entity_type)
      {
        position: section_popover_row(by_type["Position"] || []),
        assignments: section_popover_row(by_type["Assignment"] || []),
        aspirations: section_popover_row(by_type["Aspiration"] || [])
      }
    end

    def section_popover_row(items)
      items = Array(items)
      return { employee: 0, manager: 0, together: 0 } if items.empty?

      count = items.size.to_f
      {
        employee: (items.count { |item| workflow_employee_done?(item) } / count * 100).round(0),
        manager: (items.count { |item| workflow_manager_done?(item) } / count * 100).round(0),
        together: (items.count { |item| item.status == HEALTHY } / count * 100).round(0)
      }
    end

    def workflow_employee_done?(item)
      inputs = item.inputs
      return true if inputs["open_employee_completed"]
      return true if item.healthy? && !inputs["open_check_in_present"]

      false
    end

    def workflow_manager_done?(item)
      inputs = item.inputs
      return true if inputs["open_manager_completed"]
      return true if item.healthy? && !inputs["open_check_in_present"]

      false
    end

    def status_counts_for_items(items)
      EngagementHealth::STATUSES.index_with(0).tap do |counts|
        Array(items).each do |item|
          counts[item.status] += 1 if counts.key?(item.status)
        end
      end
    end

    def average_healthy_percentage_for_teammates(records_by_teammate_id, teammate_ids)
      return 0.0 if teammate_ids.blank?

      sum = teammate_ids.sum do |teammate_id|
        healthy_percentage(clarity_items(records_by_teammate_id[teammate_id] || []))
      end
      (sum / teammate_ids.size).round(1)
    end

    def crystal_clear_count(records_by_teammate_id, teammate_ids)
      teammate_ids.count do |teammate_id|
        fully_clear?(records_by_teammate_id[teammate_id] || [])
      end
    end

    def section_status_breakdown(records)
      by_type = clarity_items(records).group_by(&:entity_type)
      {
        aspirations: status_counts_for_items(by_type["Aspiration"] || []),
        assignments: status_counts_for_items(by_type["Assignment"] || []),
        position: status_counts_for_items(by_type["Position"] || [])
      }
    end

    def csv_section_status_percents(records, entity_type:)
      items = items_for_entity_type(records, entity_type: entity_type)
      counts = status_counts_for_items(items)
      total = counts.values.sum.to_f
      return zero_status_percents if total.zero?

      EngagementHealth::STATUSES.index_with do |status|
        (counts[status].to_f / total * 100).round(1)
      end
    end

    def zero_status_percents
      EngagementHealth::STATUSES.index_with { 0.0 }
    end
  end
end
