# frozen_string_literal: true

module EngagementHealth
  # Maps Gruuv Health status + open/closed check-in workflow into action-bar
  # colors and snapshot fields stored on Required Clarity item inputs.
  class WorkflowSnapshot
    ACTION_BAR_COLORS = %w[
      light_green
      light_blue
      light_purple
      orange
      red
      green_striped
      neon_green_striped
      anomaly_gray
    ].freeze

    def self.call(status:, open_check_in:, last_closed_check_in:, reference_time: Time.current, days_since_last_event: nil)
      new(
        status: status,
        open_check_in: open_check_in,
        last_closed_check_in: last_closed_check_in,
        reference_time: reference_time,
        days_since_last_event: days_since_last_event
      ).call
    end

    def initialize(status:, open_check_in:, last_closed_check_in:, reference_time:, days_since_last_event:)
      @status = status
      @open_check_in = open_check_in
      @last_closed_check_in = last_closed_check_in
      @reference_time = reference_time
      @days_since_last_event = days_since_last_event
    end

    def call
      open_present = open_check_in.present?
      employee_done = side_completed?(open_check_in, :employee)
      manager_done = side_completed?(open_check_in, :manager)
      both_done = employee_done && manager_done
      neither_done = !employee_done && !manager_done
      previous_acknowledged = previous_acknowledged?

      action_bar_color = resolve_action_bar_color(
        open_present: open_present,
        employee_done: employee_done,
        manager_done: manager_done,
        both_done: both_done,
        neither_done: neither_done,
        previous_acknowledged: previous_acknowledged
      )

      {
        "open_check_in_present" => open_present,
        "open_check_in_id" => open_check_in&.id,
        "open_employee_completed" => employee_done,
        "open_manager_completed" => manager_done,
        "open_ready_for_finalization" => open_present && both_done,
        "previous_finalized_acknowledged" => previous_acknowledged,
        "previous_finalized_awaiting_acknowledgment" => last_closed_check_in.present? && !previous_acknowledged,
        "days_until_warning" => days_until_warning,
        "action_bar_color" => action_bar_color
      }
    end

    private

    attr_reader :status, :open_check_in, :last_closed_check_in, :reference_time, :days_since_last_event

    def resolve_action_bar_color(open_present:, employee_done:, manager_done:, both_done:, neither_done:, previous_acknowledged:)
      if open_present
        return "light_green" if both_done
        return "light_blue" if employee_done && !manager_done
        return "light_purple" if manager_done && !employee_done

        if neither_done
          return "red" if status == NEEDS_ATTENTION
          return "orange" if status == WARNING
          if status == HEALTHY
            return "anomaly_gray" if last_closed_check_in.blank?
            return previous_acknowledged ? "neon_green_striped" : "green_striped"
          end
        end
      else
        return "red" if status == NEEDS_ATTENTION
        return "orange" if status == WARNING
        if status == HEALTHY
          return "anomaly_gray" if last_closed_check_in.blank?
          return previous_acknowledged ? "neon_green_striped" : "green_striped"
        end
      end

      "anomaly_gray"
    end

    def previous_acknowledged?
      ack_at = last_closed_check_in&.maap_snapshot&.employee_acknowledged_at
      ack_at.present? && ack_at <= reference_time
    end

    def side_completed?(check_in, side)
      return false if check_in.blank?

      timestamp = side == :employee ? check_in.employee_completed_at : check_in.manager_completed_at
      timestamp.present? && timestamp <= reference_time
    end

    def days_until_warning
      return 0 unless status == HEALTHY
      return nil if days_since_last_event.nil?

      remaining = Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS + 1 - days_since_last_event
      remaining.positive? ? remaining : 0
    end
  end
end
