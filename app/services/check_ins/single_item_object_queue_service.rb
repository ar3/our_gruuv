# frozen_string_literal: true

module CheckIns
  # Lightweight viewer-perspective queue for 1-by-1 check-in pages.
  # Reuses Engagement Health status + open-check-in workflow inputs (same as Up Next),
  # but treats "your turn" as only the viewer's incomplete side — not joint review.
  class SingleItemObjectQueueService
    VIEWER_STATES = %i[your_turn waiting review_together clear].freeze

    def self.call(items:, engagement_health_records:, teammate:, current_person:, current_type:, current_id: nil)
      new(
        items: items,
        engagement_health_records: engagement_health_records,
        teammate: teammate,
        current_person: current_person,
        current_type: current_type,
        current_id: current_id
      ).call
    end

    def initialize(items:, engagement_health_records:, teammate:, current_person:, current_type:, current_id: nil)
      @items = Array(items)
      @engagement_health_records = engagement_health_records
      @teammate = teammate
      @current_person = current_person
      @current_type = current_type&.to_sym
      @current_id = current_id
    end

    def call
      eh_by_key = EngagementHealth::UpNextSupport.index_items_by_key(engagement_health_records)
      rows = items.map { |item| build_row(item, eh_by_key) }
      rows = sort_rows(rows)

      {
        rows: rows,
        your_turn_count: rows.count { |row| row[:viewer_state] == :your_turn },
        total_count: rows.size
      }
    end

    private

    attr_reader :items, :engagement_health_records, :teammate, :current_person, :current_type, :current_id

    def manager_perspective?
      current_person.blank? || current_person.id != teammate.person_id
    end

    def build_row(item, eh_by_key)
      eh_item = EngagementHealth::UpNextSupport.find_item(eh_by_key, item)
      viewer_state = viewer_state_for(eh_item, item)
      status = eh_item&.status || status_from_bucket(item[:bucket])

      {
        item: item,
        type: item[:type],
        id: item[:id],
        name: item[:name],
        status: status,
        viewer_state: viewer_state,
        your_turn: viewer_state == :your_turn,
        current: current_item?(item),
        open_check_in_present: open_check_in_present?(eh_item, item),
        last_finalized_at: last_finalized_at_for(eh_item, item)
      }
    end

    def last_finalized_at_for(eh_item, item)
      raw = eh_item&.inputs&.dig("last_event_at").presence || item[:bucket_activity_at]
      return nil if raw.blank?
      return raw if raw.respond_to?(:to_time)

      Time.zone.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def viewer_state_for(eh_item, item)
      status = eh_item&.status || status_from_bucket(item[:bucket])
      return :clear if status.blank? || status == EngagementHealth::HEALTHY

      inputs = eh_item&.inputs || {}
      if inputs["open_check_in_present"]
        my_done = manager_perspective? ? inputs["open_manager_completed"] : inputs["open_employee_completed"]
        other_done = manager_perspective? ? inputs["open_employee_completed"] : inputs["open_manager_completed"]
        return :your_turn unless my_done
        return :waiting unless other_done

        :review_together
      elsif item[:my_side_completed_at].present?
        :waiting
      else
        :your_turn
      end
    end

    def open_check_in_present?(eh_item, item)
      return true if eh_item&.inputs&.dig("open_check_in_present")
      return true if item[:my_side_completed_at].present?

      false
    end

    def status_from_bucket(bucket)
      case bucket&.to_sym
      when :green then EngagementHealth::HEALTHY
      when :yellow then EngagementHealth::WARNING
      else EngagementHealth::NEEDS_ATTENTION
      end
    end

    def current_item?(item)
      return false unless item[:type] == current_type

      if item[:type] == :position
        current_id.blank? || item[:id].to_i == current_id.to_i
      else
        item[:id].to_i == current_id.to_i
      end
    end

    def sort_rows(rows)
      type_order = EngagementHealth::UpNextSupport::TYPE_ORDER
      rows.sort_by do |row|
        your_turn_rank = row[:your_turn] ? 0 : 1
        severity = EngagementHealth.status_severity_rank(row[:status])
        type_rank = type_order[row[:type]] || 99
        name = row[:name].to_s.downcase
        [your_turn_rank, severity, type_rank, name]
      end
    end
  end
end
