# frozen_string_literal: true

module CheckIns
  # Planned vs. reflection energy bars for bulk assignment check-in (employee view).
  class AssignmentEnergyAllocationSummary
    Segment = Data.define(:assignment_id, :name, :value, :display_weight, :color)

    ALERT_SUCCESS = :success
    ALERT_WARNING = :warning
    ALERT_DANGER = :danger

    PALETTE = %w[
      #0d6efd #198754 #ffc107 #dc3545 #6f42c1 #fd7e14
      #20c997 #d63384 #0dcaf0 #6610f2 #adb5bd #495057
    ].freeze

    attr_reader :planned_segments,
                :reflection_segments,
                :planned_total,
                :reflection_total,
                :reflection_alert_band,
                :color_by_assignment_id,
                :legend_entries

    def self.for_bulk_check_in(teammate:, reflection_check_ins:, organization: teammate.organization)
      new(
        teammate: teammate,
        reflection_check_ins: reflection_check_ins,
        organization: organization
      ).build
    end

    def initialize(teammate:, reflection_check_ins:, organization:)
      @teammate = teammate
      @reflection_check_ins = Array(reflection_check_ins)
      @organization = organization
    end

    def build
      active_tenures = load_active_tenures
      assignment_ids = (
        active_tenures.map(&:assignment_id) + @reflection_check_ins.map(&:assignment_id)
      ).uniq
      @color_by_assignment_id = assign_colors(assignment_ids)

      @planned_segments = build_planned_segments(active_tenures)
      @planned_total = @planned_segments.sum(&:value)

      @reflection_segments = build_reflection_segments(@reflection_check_ins)
      @reflection_total = @reflection_segments.sum(&:value)
      @reflection_alert_band =
        if @reflection_segments.empty?
          nil
        else
          alert_band_for(@reflection_total)
        end

      @legend_entries = build_legend_entries
      self
    end

    def reflection_empty?
      @reflection_segments.empty?
    end

    def planned_popover_text(employee_name:, manager_name:)
      "How #{employee_name} & #{manager_name} thought #{employee_name} would distribute their energy"
    end

    def reflection_popover_text(employee_name:)
      "Reflecting on the recent past; how #{employee_name} actually distributed their energy"
    end

    def planned_bar_payload
      bar_payload(@planned_segments, @planned_total, alert_band: nil)
    end

    def reflection_bar_payload
      bar_payload(@reflection_segments, @reflection_total, alert_band: @reflection_alert_band)
    end

    # assignment_id => anticipated % (active tenures only)
    def planned_by_assignment_id
      @planned_segments.each_with_object({}) do |segment, hash|
        hash[segment.assignment_id] = segment.value
      end
    end

    # assignment_id => { name:, planned: Integer|nil }
    def assignment_metadata_by_id
      metadata = {}
      @planned_segments.each do |segment|
        metadata[segment.assignment_id] = { name: segment.name, planned: segment.value }
      end
      @reflection_check_ins.each do |check_in|
        id = check_in.assignment_id
        metadata[id] ||= { name: check_in.assignment.title, planned: nil }
        metadata[id][:name] = check_in.assignment.title if metadata[id][:name].blank?
      end
      metadata
    end

    # Persisted reflection % per assignment (for pages with a single live select).
    def reflection_by_assignment_id
      @reflection_check_ins.each_with_object({}) do |check_in, hash|
        value = reflection_value_for(check_in)
        hash[check_in.assignment_id] = value if value.present?
      end
    end

    private

    def load_active_tenures
      AssignmentTenure
        .active
        .joins(:assignment)
        .where(teammate_id: @teammate.id, assignments: { company: @organization })
        .includes(:assignment)
        .order('assignments.title ASC')
    end

    def build_planned_segments(active_tenures)
      active_tenures.map do |tenure|
        value = tenure.anticipated_energy_percentage.to_i
        display_weight = value.positive? ? value : 1
        Segment.new(
          assignment_id: tenure.assignment_id,
          name: tenure.assignment.title,
          value: value,
          display_weight: display_weight,
          color: @color_by_assignment_id[tenure.assignment_id]
        )
      end
    end

    def build_reflection_segments(check_ins)
      check_ins.filter_map do |check_in|
        value = reflection_value_for(check_in)
        next if value.nil?

        Segment.new(
          assignment_id: check_in.assignment_id,
          name: check_in.assignment.title,
          value: value,
          display_weight: value,
          color: @color_by_assignment_id[check_in.assignment_id]
        )
      end
    end

    def reflection_value_for(check_in)
      raw = check_in.actual_energy_percentage
      return nil if raw.blank?

      value = raw.to_i
      return nil if value <= 0

      value
    end

    def assign_colors(assignment_ids)
      assignment_ids.each_with_index.to_h do |assignment_id, index|
        [assignment_id, PALETTE[index % PALETTE.length]]
      end
    end

    def build_legend_entries
      entries = {}
      (@planned_segments + @reflection_segments).each do |segment|
        entries[segment.assignment_id] ||= {
          assignment_id: segment.assignment_id,
          name: segment.name,
          color: segment.color
        }
      end
      entries.values.sort_by { |e| e[:name].downcase }
    end

    def alert_band_for(total)
      return ALERT_SUCCESS if total == 100
      return ALERT_WARNING if total.between?(90, 110) && total != 100

      ALERT_DANGER
    end

    def bar_payload(segments, total, alert_band:)
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
        total: total,
        alert_band: alert_band
      }
    end
  end
end
