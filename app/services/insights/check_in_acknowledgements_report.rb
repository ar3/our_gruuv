# frozen_string_literal: true

module Insights
  # Finalized check-ins in a timeframe, bucketed by acknowledgement status for Insights.
  # Only check-ins with at least one real rating (not all blank/N/A) are included.
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
        acknowledged: rows.count { |r| r.status == :acknowledged },
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
        .with_acknowledgement_relevant_rating
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
      status = check_in.employee_acknowledged? ? :acknowledged : :unacknowledged
      Row.new(
        check_in: check_in,
        teammate: check_in.teammate,
        type_label: type_label,
        item_name: item_name,
        status: status,
        status_label: status == :acknowledged ? "Acknowledged" : "Unacknowledged",
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

    def pie_chart_data(counts)
      [
        { name: "Acknowledged", y: counts[:acknowledged].to_i, color: "#198754" },
        { name: "Unacknowledged", y: counts[:unacknowledged].to_i, color: "#ffc107" }
      ].reject { |point| point[:y].zero? }
    end
  end
end
