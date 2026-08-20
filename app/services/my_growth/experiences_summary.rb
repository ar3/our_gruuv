# frozen_string_literal: true

module MyGrowth
  # Energy total, alert band, and Highcharts pie payloads for assignment energy / rating mix.
  #
  # Official row (tenure-based):
  #   energy: active tenure anticipated_energy_percentage
  #   rating: tenure energy × latest finalized official_rating
  #
  # In-flight row (per active assignment):
  #   energy: open CI + employee completed → actual_energy_percentage; else tenure anticipated
  #   rating: open CI + manager completed → manager_rating;
  #           else latest finalized official_rating (then tenure.official_rating)
  #           (weighted by in-flight energy)
  class ExperiencesSummary
    RATING_BUCKETS = {
      'working_to_meet' => { label: 'Working to Meet expectations', color: '#ffc107' },
      'meeting' => { label: 'Meeting expectations', color: '#0d6efd' },
      'exceeding' => { label: 'Exceeding Expectations', color: '#198754' },
      'no_check_in' => { label: 'No finalized check-in', color: '#6c757d' }
    }.freeze

    INFLIGHT_NO_RATING_LABEL = 'No rating yet'
    GUIDANCE_RATINGS = [1, 2, 3].freeze

    attr_reader :total_energy_percentage,
                :alert_band,
                :energy_by_assignment_chart,
                :energy_by_rating_chart,
                :energy_by_inflight_assignment_chart,
                :energy_by_inflight_rating_chart,
                :show_inflight_charts,
                :official_rating_energy_buckets,
                :inflight_rating_energy_buckets

    # Legacy aliases used by existing views/specs.
    alias energy_by_inflight_viewer_rating_chart energy_by_inflight_rating_chart
    alias show_inflight_viewer_rating_chart show_inflight_charts
    alias show_inflight_rating_chart show_inflight_charts

    def self.build(teammate:, latest_finalized_check_ins_by_assignment_id:, viewer_teammate: nil,
                   open_check_ins_by_assignment_id: {})
      new(
        teammate: teammate,
        latest_finalized_check_ins_by_assignment_id: latest_finalized_check_ins_by_assignment_id,
        viewer_teammate: viewer_teammate,
        open_check_ins_by_assignment_id: open_check_ins_by_assignment_id
      ).tap(&:compute!)
    end

    def self.for_teammate(teammate, organization: teammate.organization, viewer_teammate: nil)
      assignment_ids = teammate.active_assignment_tenures.pluck(:assignment_id)
      latest_finalized_check_ins_by_assignment_id = {}
      open_check_ins_by_assignment_id = {}

      if assignment_ids.any?
        scope = AssignmentCheckIn.where(company_teammate: teammate, assignment_id: assignment_ids)

        scope.closed
             .includes(:assignment, manager_completed_by_teammate: :person, finalized_by_teammate: :person)
             .order(official_check_in_completed_at: :desc)
             .each do |check_in|
               latest_finalized_check_ins_by_assignment_id[check_in.assignment_id] ||= check_in
             end

        scope.open
             .includes(:assignment)
             .order(check_in_started_on: :desc, id: :desc)
             .each do |check_in|
               open_check_ins_by_assignment_id[check_in.assignment_id] ||= check_in
             end
      end

      build(
        teammate: teammate,
        latest_finalized_check_ins_by_assignment_id: latest_finalized_check_ins_by_assignment_id,
        viewer_teammate: viewer_teammate,
        open_check_ins_by_assignment_id: open_check_ins_by_assignment_id
      )
    end

    def initialize(teammate:, latest_finalized_check_ins_by_assignment_id:, viewer_teammate: nil,
                   open_check_ins_by_assignment_id: {})
      @teammate = teammate
      @latest_finalized_check_ins_by_assignment_id = latest_finalized_check_ins_by_assignment_id || {}
      @viewer_teammate = viewer_teammate # retained for call-site compatibility; unused by in-flight rules
      @open_check_ins_by_assignment_id = open_check_ins_by_assignment_id || {}
      @show_inflight_charts = false
      @official_rating_energy_buckets = RATING_BUCKETS.keys.index_with { 0 }
      @inflight_rating_energy_buckets = RATING_BUCKETS.keys.index_with { 0 }
    end

    def compute!
      tenures = @teammate.active_assignment_tenures.includes(:assignment).to_a

      @energy_by_assignment_chart = build_official_energy_chart(tenures)
      @total_energy_percentage = tenures.sum { |t| t.anticipated_energy_percentage.to_i }
      @alert_band = alert_band_for(@total_energy_percentage)
      @official_rating_energy_buckets = rating_energy_buckets(tenures, :official)
      @inflight_rating_energy_buckets = rating_energy_buckets(tenures, :inflight)
      @energy_by_rating_chart = chart_points_from_buckets(@official_rating_energy_buckets)
      @energy_by_inflight_assignment_chart = build_inflight_energy_chart(tenures)
      @energy_by_inflight_rating_chart = chart_points_from_buckets(
        @inflight_rating_energy_buckets,
        no_rating_label: INFLIGHT_NO_RATING_LABEL
      )
      @show_inflight_charts = chart_data_present?
      self
    end

    def chart_data_present?
      energy_by_assignment_chart.any?
    end

    # Same chart the position OG tip references: in-flight when shown, else official.
    def guidance_rating_energy_buckets
      show_inflight_charts ? inflight_rating_energy_buckets : official_rating_energy_buckets
    end

    # Maps assignment-energy mix → Developing (1) / Accomplished (2) / Exceptional (3).
    # Nil when there is no rated energy to apply the tip against.
    def guidance_position_rating
      buckets = guidance_rating_energy_buckets
      total = buckets.values.sum
      return nil if total <= 0

      rated = buckets.fetch("working_to_meet", 0) +
              buckets.fetch("meeting", 0) +
              buckets.fetch("exceeding", 0)
      return nil if rated <= 0

      wtm_share = buckets.fetch("working_to_meet", 0).to_f / total
      exceeding_share = buckets.fetch("exceeding", 0).to_f / total

      if wtm_share > 0.20
        1
      elsif exceeding_share > 0.50 && buckets.fetch("working_to_meet", 0).zero?
        3
      else
        2
      end
    end

    private

    def alert_band_for(total)
      return :success if total == 100
      return :warning if total.between?(90, 110) && total != 100

      :danger
    end

    def open_check_in_for(tenure)
      check_in = @open_check_ins_by_assignment_id[tenure.assignment_id]
      return nil if check_in.blank? || !check_in.open?

      check_in
    end

    def official_energy_for(tenure)
      tenure.anticipated_energy_percentage.to_i
    end

    def inflight_energy_for(tenure)
      open = open_check_in_for(tenure)
      if open&.employee_completed? && !open.actual_energy_percentage.nil?
        open.actual_energy_percentage.to_i
      else
        official_energy_for(tenure)
      end
    end

    def inflight_rating_for(tenure)
      open = open_check_in_for(tenure)
      if open&.manager_completed? && open.manager_rating.present?
        open.manager_rating
      else
        latest_finalized_rating_for(tenure)
      end
    end

    def latest_finalized_rating_for(tenure)
      @latest_finalized_check_ins_by_assignment_id[tenure.assignment_id]&.official_rating.presence ||
        tenure.try(:official_rating)
    end

    def build_official_energy_chart(tenures)
      tenures.filter_map do |tenure|
        energy = official_energy_for(tenure)
        next if energy <= 0

        { name: tenure.assignment.title, y: energy }
      end
    end

    def build_inflight_energy_chart(tenures)
      tenures.filter_map do |tenure|
        energy = inflight_energy_for(tenure)
        next if energy <= 0

        { name: tenure.assignment.title, y: energy }
      end
    end

    def rating_energy_buckets(tenures, mode)
      buckets = RATING_BUCKETS.keys.index_with { 0 }

      tenures.each do |tenure|
        energy = mode == :inflight ? inflight_energy_for(tenure) : official_energy_for(tenure)
        next if energy <= 0

        rating = if mode == :inflight
          inflight_rating_for(tenure)
        else
          @latest_finalized_check_ins_by_assignment_id[tenure.assignment_id]&.official_rating
        end
        key = RATING_BUCKETS.key?(rating) ? rating : "no_check_in"
        buckets[key] += energy
      end

      buckets
    end

    def chart_points_from_buckets(buckets, no_rating_label: nil)
      RATING_BUCKETS.filter_map do |key, meta|
        energy = buckets[key]
        next if energy.zero?

        label = key == "no_check_in" && no_rating_label.present? ? no_rating_label : meta[:label]
        { name: label, y: energy, color: meta[:color] }
      end
    end
  end
end
