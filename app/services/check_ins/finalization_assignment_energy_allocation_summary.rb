# frozen_string_literal: true

module CheckIns
  # Current vs. updated forecast energy bars on assignment finalization.
  class FinalizationAssignmentEnergyAllocationSummary
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

    def self.for_finalization(teammate:, assignment_check_ins:, organization: teammate.organization)
      new(
        teammate: teammate,
        assignment_check_ins: assignment_check_ins,
        organization: organization
      ).build
    end

    def initialize(teammate:, assignment_check_ins:, organization:)
      @teammate = teammate
      @assignment_check_ins = Array(assignment_check_ins)
      @organization = organization
    end

    def build
      contexts = build_contexts
      return self if contexts.empty?

      assignment_ids = contexts.map(&:assignment_id)
      @color_by_assignment_id = assign_colors(assignment_ids)
      @current_forecast_by_assignment_id = {}
      @employee_actual_by_assignment_id = {}
      @updated_forecast_by_assignment_id = {}
      @assignment_metadata_by_id = {}

      contexts.each do |ctx|
        forecast = tenure_forecast(ctx.tenure)
        @current_forecast_by_assignment_id[ctx.assignment_id] = forecast
        @employee_actual_by_assignment_id[ctx.assignment_id] = employee_actual_for(ctx.check_in)
        @updated_forecast_by_assignment_id[ctx.assignment_id] = updated_value_for(ctx)
        @assignment_metadata_by_id[ctx.assignment_id] = {
          name: ctx.name,
          current_forecast: forecast,
          employee_actual: @employee_actual_by_assignment_id[ctx.assignment_id]
        }
      end

      @current_segments = build_current_segments(contexts)
      @current_total = @current_segments.sum(&:value)
      @updated_segments = build_updated_segments(contexts)
      @updated_total = @updated_segments.sum(&:value)
      @updated_alert_band = alert_band_for(@updated_total)
      @legend_entries = build_legend_entries
      self
    end

    def contexts?
      @assignment_metadata_by_id.present?
    end

    def updated_empty?
      @updated_segments.empty?
    end

    def current_popover_text(employee_name:, manager_name:)
      "A mixture of how #{manager_name} and #{employee_name} thought #{employee_name} would spend their energy, mixed with #{employee_name} reflecting on how they actually distributed their energy."
    end

    def updated_popover_text(employee_name:, manager_name:)
      "How #{employee_name} & #{manager_name} believe #{employee_name} will distribute their energy until the next check-in"
    end

    def current_bar_payload
      bar_payload(@current_segments, @current_total)
    end

    def updated_bar_payload
      bar_payload(@updated_segments, @updated_total)
    end

    private

    Context = Struct.new(:assignment_id, :name, :check_in, :tenure, keyword_init: true)

    def build_contexts
      check_ins_by_assignment = @assignment_check_ins.index_by(&:assignment_id)
      tenures_by_assignment = load_active_tenures_by_assignment
      assignment_ids = (tenures_by_assignment.keys + check_ins_by_assignment.keys).uniq
      return [] if assignment_ids.empty?

      assignment_ids.filter_map do |assignment_id|
        check_in = check_ins_by_assignment[assignment_id]
        tenure = tenures_by_assignment[assignment_id]
        next if check_in.blank? && tenure.blank?

        name = check_in&.assignment&.title || tenure&.assignment&.title || "Assignment #{assignment_id}"
        Context.new(assignment_id: assignment_id, name: name, check_in: check_in, tenure: tenure)
      end.sort_by { |ctx| ctx.name.downcase }
    end

    def load_active_tenures_by_assignment
      AssignmentTenure
        .active
        .joins(:assignment)
        .where(teammate_id: @teammate.id, assignments: { company: @organization })
        .includes(:assignment)
        .index_by(&:assignment_id)
    end

    def build_current_segments(contexts)
      contexts.filter_map do |ctx|
        value = current_value_for(ctx)
        next if value.nil?

        segment_for(ctx, value)
      end
    end

    def build_updated_segments(contexts)
      contexts.filter_map do |ctx|
        value = @updated_forecast_by_assignment_id[ctx.assignment_id]
        next if value.nil? || value <= 0

        segment_for(ctx, value)
      end
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

    # Same as the left bar unless this assignment is ready for finalization (then use finalization energy).
    def updated_value_for(ctx)
      if ctx.check_in&.ready_for_finalization?
        return finalization_energy_for(ctx)
      end

      current_value_for(ctx)
    end

    def finalization_energy_for(ctx)
      raw = ctx.check_in.actual_energy_percentage.presence || tenure_forecast(ctx.tenure)
      return nil if raw.blank?

      raw.to_i
    end

    def tenure_forecast(tenure)
      return nil if tenure.blank?

      tenure.anticipated_energy_percentage.to_i
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
