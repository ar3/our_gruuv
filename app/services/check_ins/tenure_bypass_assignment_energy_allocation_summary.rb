# frozen_string_literal: true

module CheckIns
  # Current vs. updated forecast energy bars on assignment tenure check-in bypass.
  # Left: active tenures (employee reflection overrides tenure when applicable).
  # Right: table rows with anticipated energy % > 0 (live from assignment_tenures selects).
  class TenureBypassAssignmentEnergyAllocationSummary
    include EnergyAllocationConstants

    Segment = Data.define(:assignment_id, :name, :value, :display_weight, :color)

    attr_reader :current_segments,
                :updated_segments,
                :current_total,
                :updated_total,
                :updated_alert_band,
                :color_by_assignment_id,
                :legend_entries,
                :current_forecast_by_assignment_id,
                :employee_actual_by_assignment_id,
                :updated_forecast_by_assignment_id,
                :assignment_metadata_by_id

    def self.for_tenure_bypass(teammate:, assignments:, assignment_data:, organization: teammate.organization)
      new(
        teammate: teammate,
        assignments: assignments,
        assignment_data: assignment_data,
        organization: organization
      ).build
    end

    def initialize(teammate:, assignments:, assignment_data:, organization:)
      @teammate = teammate
      @assignments = Array(assignments)
      @assignment_data = assignment_data || {}
      @organization = organization
    end

    def build
      @open_check_ins_by_assignment = load_open_check_ins_by_assignment
      active_tenures = load_active_tenures
      current_contexts = build_current_contexts(active_tenures)

      assignment_ids = (
        current_contexts.map(&:assignment_id) +
        @assignments.map(&:id)
      ).uniq

      return self if assignment_ids.empty?

      @color_by_assignment_id = assign_colors(assignment_ids)
      @current_forecast_by_assignment_id = {}
      @employee_actual_by_assignment_id = {}
      @updated_forecast_by_assignment_id = {}
      @assignment_metadata_by_id = {}

      current_contexts.each do |ctx|
        forecast = tenure_forecast(ctx.tenure)
        @current_forecast_by_assignment_id[ctx.assignment_id] = forecast
        @employee_actual_by_assignment_id[ctx.assignment_id] = employee_actual_for(ctx.check_in)
        @assignment_metadata_by_id[ctx.assignment_id] ||= metadata_entry(ctx)
      end

      @assignments.each do |assignment|
        @assignment_metadata_by_id[assignment.id] ||= {
          name: assignment.title,
          current_forecast: nil,
          employee_actual: nil
        }
        value = table_row_forecast_value(assignment)
        @updated_forecast_by_assignment_id[assignment.id] = value if value.present? && value.positive?
      end

      @current_segments = build_current_segments(current_contexts)
      @current_total = @current_segments.sum(&:value)
      @updated_segments = build_updated_segments
      @updated_total = @updated_segments.sum(&:value)
      @updated_alert_band = alert_band_for(@updated_total)
      @legend_entries = build_legend_entries
      self
    end

    def contexts?
      @assignment_metadata_by_id.present?
    end

    def updated_empty?
      @updated_segments.blank?
    end

    def current_popover_text(employee_name:, manager_name:)
      "How #{employee_name}'s Assignment-energy is split across active tenures today. " \
        "When #{employee_name} has completed their side of an open check-in, that reflection replaces the tenure forecast for that assignment."
    end

    def updated_popover_text(employee_name:, manager_name: nil)
      "How #{employee_name}'s Assignment-energy will be split after you save the Anticipated Energy % values below. " \
        "Assignments at 0% are omitted from this bar (and end active tenure when saved)."
    end

    def current_bar_payload
      bar_payload(@current_segments, @current_total)
    end

    def updated_bar_payload
      bar_payload(@updated_segments, @updated_total)
    end

    private

    Context = Struct.new(:assignment_id, :name, :check_in, :tenure, keyword_init: true)

    def load_open_check_ins_by_assignment
      AssignmentCheckIn
        .open
        .joins(:assignment)
        .where(company_teammate: @teammate, assignments: { company: @organization })
        .includes(:assignment)
        .index_by(&:assignment_id)
    end

    def load_active_tenures
      AssignmentTenure
        .active
        .joins(:assignment)
        .where(teammate_id: @teammate.id, assignments: { company: @organization })
        .includes(:assignment)
        .order('assignments.title ASC')
    end

    def build_current_contexts(active_tenures)
      active_tenures.map do |tenure|
        Context.new(
          assignment_id: tenure.assignment_id,
          name: tenure.assignment.title,
          tenure: tenure,
          check_in: @open_check_ins_by_assignment[tenure.assignment_id]
        )
      end
    end

    def build_current_segments(contexts)
      contexts.filter_map do |ctx|
        value = current_value_for(ctx)
        next if value.nil?

        segment_for(ctx, value)
      end
    end

    def build_updated_segments
      @assignments.filter_map do |assignment|
        value = @updated_forecast_by_assignment_id[assignment.id]
        next if value.nil? || value <= 0

        segment_for(
          Context.new(
            assignment_id: assignment.id,
            name: assignment.title,
            tenure: nil,
            check_in: nil
          ),
          value
        )
      end.sort_by { |s| s.name.downcase }
    end

    def current_value_for(ctx)
      actual = employee_actual_for(ctx.check_in)
      return actual if actual.present?

      tenure_forecast(ctx.tenure)
    end

    def employee_actual_for(check_in)
      return nil if check_in.blank?
      return nil unless check_in.open? && check_in.employee_completed?

      raw = check_in.actual_energy_percentage
      return nil if raw.blank?

      value = raw.to_i
      return nil if value <= 0

      value
    end

    def table_row_forecast_value(assignment)
      active_tenure = active_tenure_for(assignment)
      return nil if active_tenure.blank?

      active_tenure.anticipated_energy_percentage&.to_i
    end

    def active_tenure_for(assignment)
      latest = @assignment_data.dig(assignment.id, :latest_tenure)
      return nil if latest.blank?
      return nil if latest.ended_at.present?

      latest
    end

    def tenure_forecast(tenure)
      return nil if tenure.blank?

      tenure.anticipated_energy_percentage.to_i
    end

    def metadata_entry(ctx)
      {
        name: ctx.name,
        current_forecast: tenure_forecast(ctx.tenure),
        employee_actual: employee_actual_for(ctx.check_in)
      }
    end

    def segment_for(ctx, value)
      display_weight = value.positive? ? value : 1
      Segment.new(
        assignment_id: ctx.assignment_id,
        name: ctx.name,
        value: value,
        display_weight: display_weight,
        color: @color_by_assignment_id[ctx.assignment_id]
      )
    end

    def build_legend_entries
      entries = {}
      (@current_segments + @updated_segments).each do |segment|
        entries[segment.assignment_id] ||= {
          assignment_id: segment.assignment_id,
          name: segment.name,
          color: segment.color
        }
      end
      entries.values.sort_by { |e| e[:name].downcase }
    end

    def bar_payload(segments, total)
      {
        segments: segments.map do |s|
          {
            assignment_id: s.assignment_id,
            name: s.name,
            value: s.value,
            display_weight: s.display_weight,
            color: s.color
          }
        end,
        total: total
      }
    end
  end
end
