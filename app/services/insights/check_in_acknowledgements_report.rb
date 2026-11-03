# frozen_string_literal: true

module Insights
  # Finalized check-ins in a timeframe, bucketed by acknowledgement status for Insights.
  # Only check-ins with at least one real rating (not all blank/N/A) are included.
  #
  # Statuses:
  # - acknowledged: employee acknowledged
  # - unacknowledged: still awaiting ack (latest finalized for the item)
  # - skipped: no longer ackable (superseded by a newer finalized check-in)
  class CheckInAcknowledgementsReport
    CHECK_IN_CLASSES = [AspirationCheckIn, AssignmentCheckIn, PositionCheckIn].freeze

    STATUS_LABELS = {
      acknowledged: "Acknowledged",
      unacknowledged: "Unacknowledged",
      skipped: "Skipped Ack"
    }.freeze

    Row = Struct.new(
      :check_in,
      :teammate,
      :teammate_name,
      :manager_name,
      :type_label,
      :item_name,
      :item_path,
      :status,
      :status_label,
      :finalized_at,
      :acknowledged_at,
      :notes,
      keyword_init: true
    )

    def self.call(organization:, teammate_ids:, range: nil, status_filter: "all")
      new(
        organization: organization,
        teammate_ids: teammate_ids,
        range: range,
        status_filter: status_filter
      ).call
    end

    def initialize(organization:, teammate_ids:, range:, status_filter: "all")
      @organization = organization
      @teammate_ids = Array(teammate_ids).map(&:to_i).uniq
      @range = range
      @status_filter = status_filter.to_s
      @latest_finalized_ids = {}
    end

    def call
      all_rows = load_rows
      counts = {
        acknowledged: all_rows.count { |r| r.status == :acknowledged },
        unacknowledged: all_rows.count { |r| r.status == :unacknowledged },
        skipped: all_rows.count { |r| r.status == :skipped }
      }
      rows = filter_rows_by_status(all_rows)
      {
        rows: rows,
        counts: counts,
        total: all_rows.size,
        filtered_total: rows.size,
        pie_chart_data: pie_chart_data(counts)
      }
    end

    private

    def load_rows
      return [] if @teammate_ids.empty?

      CHECK_IN_CLASSES.flat_map { |klass| rows_for(klass) }
        .sort_by { |row| [-row.finalized_at.to_i, row.type_label, row.item_name.to_s.downcase] }
    end

    def filter_rows_by_status(rows)
      case @status_filter
      when "acknowledged"
        rows.select { |r| r.status == :acknowledged }
      when "unacknowledged"
        rows.select { |r| r.status == :unacknowledged }
      when "skipped"
        rows.select { |r| r.status == :skipped }
      else
        rows
      end
    end

    def rows_for(klass)
      scope = klass
        .where(teammate_id: @teammate_ids)
        .closed
        .with_acknowledgement_relevant_rating
      scope = scope.where(official_check_in_completed_at: @range) if @range

      teammate_includes = { company_teammate: [:person, { employment_tenures: { manager_teammate: :person } }] }
      case klass.name
      when "AspirationCheckIn"
        scope = scope.includes(:aspiration, :finalized_by_teammate, **teammate_includes)
      when "AssignmentCheckIn"
        scope = scope.includes(:assignment, :finalized_by_teammate, **teammate_includes)
      when "PositionCheckIn"
        scope = scope.includes(:finalized_by_teammate, employment_tenure: :position, **teammate_includes)
      end

      scope.to_a.map { |check_in| build_row(check_in) }
    end

    def build_row(check_in)
      type_label, item_name = subject_labels(check_in)
      status = status_for(check_in)
      teammate = check_in.teammate
      Row.new(
        check_in: check_in,
        teammate: teammate,
        teammate_name: teammate&.person&.display_name.presence || "—",
        manager_name: teammate&.current_manager&.casual_name.presence || "—",
        type_label: type_label,
        item_name: item_name,
        item_path: one_by_one_path_for(check_in, teammate),
        status: status,
        status_label: STATUS_LABELS.fetch(status),
        finalized_at: check_in.official_check_in_completed_at,
        acknowledged_at: check_in.employee_acknowledged_at,
        notes: check_in.employee_acknowledgement_notes
      )
    end

    def status_for(check_in)
      return :acknowledged if check_in.employee_acknowledged?
      return :unacknowledged if latest_finalized_for_item?(check_in)

      :skipped
    end

    def latest_finalized_for_item?(check_in)
      latest_finalized_id_for(check_in) == check_in.id
    end

    def latest_finalized_id_for(check_in)
      key = latest_finalized_cache_key(check_in)
      return @latest_finalized_ids[key] if @latest_finalized_ids.key?(key)

      @latest_finalized_ids[key] =
        case check_in
        when PositionCheckIn
          PositionCheckIn.latest_finalized_for(check_in.teammate)&.id
        when AssignmentCheckIn
          AssignmentCheckIn.latest_finalized_for(check_in.teammate, check_in.assignment)&.id
        when AspirationCheckIn
          AspirationCheckIn.latest_finalized_for(check_in.teammate, check_in.aspiration)&.id
        end
    end

    def latest_finalized_cache_key(check_in)
      case check_in
      when PositionCheckIn
        [:position, check_in.teammate_id]
      when AssignmentCheckIn
        [:assignment, check_in.teammate_id, check_in.assignment_id]
      when AspirationCheckIn
        [:aspiration, check_in.teammate_id, check_in.aspiration_id]
      else
        [:other, check_in.class.name, check_in.id]
      end
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

    def one_by_one_path_for(check_in, teammate)
      return if teammate.blank? || @organization.blank?

      routes = Rails.application.routes.url_helpers
      case check_in
      when AspirationCheckIn
        return if check_in.aspiration.blank?

        "#{routes.organization_teammate_aspiration_path(@organization, teammate, check_in.aspiration)}#research-all-check-ins"
      when AssignmentCheckIn
        return if check_in.assignment.blank?

        "#{routes.organization_teammate_assignment_path(@organization, teammate, check_in.assignment)}#research-all-check-ins"
      when PositionCheckIn
        "#{routes.position_check_in_organization_teammate_path(@organization, teammate)}#research-prior-check-ins"
      end
    end

    def pie_chart_data(counts)
      [
        { name: "Acknowledged", y: counts[:acknowledged].to_i, color: "#198754" },
        { name: "Unacknowledged", y: counts[:unacknowledged].to_i, color: "#ffc107" },
        { name: "Skipped Ack", y: counts[:skipped].to_i, color: "#6c757d" }
      ].reject { |point| point[:y].zero? }
    end
  end
end
