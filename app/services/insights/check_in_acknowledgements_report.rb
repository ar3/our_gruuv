# frozen_string_literal: true

module Insights
  # Finalized check-ins in a timeframe, bucketed by acknowledgement status for Insights.
  class CheckInAcknowledgementsReport
    CHECK_IN_CLASSES = [AspirationCheckIn, AssignmentCheckIn, PositionCheckIn].freeze

    Row = Struct.new(
      :check_in,
      :teammate,
      :type_label,
      :item_name,
      :status,
      :status_label,
      :finalized_at,
      :acknowledged_at,
      :notes,
      keyword_init: true
    )

    def self.call(organization:, teammate_ids:, range: nil)
      new(organization: organization, teammate_ids: teammate_ids, range: range).call
    end

    def initialize(organization:, teammate_ids:, range:)
      @organization = organization
      @teammate_ids = Array(teammate_ids).map(&:to_i).uniq
      @range = range
    end

    def call
      rows = load_rows
      counts = {
        agree: rows.count { |r| r.status == :agree },
        disagree: rows.count { |r| r.status == :disagree },
        unacknowledged: rows.count { |r| r.status == :unacknowledged }
      }
      {
        rows: rows,
        counts: counts,
        total: rows.size,
        pie_chart_data: pie_chart_data(counts)
      }
    end

    private

    def load_rows
      return [] if @teammate_ids.empty?

      CHECK_IN_CLASSES.flat_map { |klass| rows_for(klass) }
        .sort_by { |row| [-row.finalized_at.to_i, row.type_label, row.item_name.to_s.downcase] }
    end

    def rows_for(klass)
      scope = klass
        .where(teammate_id: @teammate_ids)
        .closed
      scope = scope.where(official_check_in_completed_at: @range) if @range

      case klass.name
      when "AspirationCheckIn"
        scope = scope.includes(:aspiration, :finalized_by_teammate, company_teammate: :person)
      when "AssignmentCheckIn"
        scope = scope.includes(:assignment, :finalized_by_teammate, company_teammate: :person)
      when "PositionCheckIn"
        scope = scope.includes(:finalized_by_teammate, company_teammate: :person, employment_tenure: :position)
      end

      scope.to_a.map { |check_in| build_row(check_in) }
    end

    def build_row(check_in)
      type_label, item_name = subject_labels(check_in)
      status = acknowledgement_status(check_in)
      Row.new(
        check_in: check_in,
        teammate: check_in.teammate,
        type_label: type_label,
        item_name: item_name,
        status: status,
        status_label: status_label(status),
        finalized_at: check_in.official_check_in_completed_at,
        acknowledged_at: check_in.employee_acknowledged_at,
        notes: check_in.employee_acknowledgement_notes
      )
    end

    def subject_labels(check_in)
      case check_in
      when AspirationCheckIn
        ["Aspirational Value", check_in.aspiration&.name.presence || "Aspiration"]
      when AssignmentCheckIn
        ["Assignment", check_in.assignment&.title.presence || "Assignment"]
      when PositionCheckIn
        ["Position", check_in.employment_tenure&.position&.display_name.presence || "Position"]
      else
        ["Check-in", "Item"]
      end
    end

    def acknowledgement_status(check_in)
      return :unacknowledged unless check_in.employee_acknowledged?
      return :agree if check_in.employee_acknowledgement_agree?
      return :disagree if check_in.employee_acknowledgement_disagree?

      :unacknowledged
    end

    def status_label(status)
      case status
      when :agree then "Agreed"
      when :disagree then "Disagreed"
      else "Unacknowledged"
      end
    end

    def pie_chart_data(counts)
      [
        { name: "Agreed", y: counts[:agree].to_i, color: "#198754" },
        { name: "Unacknowledged", y: counts[:unacknowledged].to_i, color: "#ffc107" },
        { name: "Disagreed", y: counts[:disagree].to_i, color: "#dc3545" }
      ].reject { |point| point[:y].zero? }
    end
  end
end
