# frozen_string_literal: true

module MyGrowth
  # Energy total, alert band, and Highcharts pie payloads for assignment energy / rating mix.
  #
  # Official rating pie: active tenure energy × latest finalized official_rating.
  # In-flight pies / alert: per active assignment —
  #   energy: open CI + employee completed → actual_energy_percentage; else tenure anticipated
  #   rating: open CI + manager completed → manager_rating; else tenure official_rating
  class ExperiencesSummary
    RATING_BUCKETS = {
      'working_to_meet' => { label: 'Working to Meet expectations', color: '#ffc107' },
      'meeting' => { label: 'Meeting expectations', color: '#0d6efd' },
      'exceeding' => { label: 'Exceeding Expectations', color: '#198754' },
      'no_check_in' => { label: 'No finalized check-in', color: '#6c757d' }
    }.freeze

    INFLIGHT_NO_RATING_LABEL = 'No rating yet'

    attr_reader :total_energy_percentage,
                :alert_band,
                :energy_by_assignment_chart,
                :energy_by_rating_chart,
                :energy_by_inflight_rating_chart,
                :show_inflight_rating_chart

    # Legacy aliases used by existing views/specs.
    alias energy_by_inflight_viewer_rating_chart energy_by_inflight_rating_chart
    alias show_inflight_viewer_rating_chart show_inflight_rating_chart

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
      @show_inflight_rating_chart = false
    end

    def compute!
      tenures = @teammate.active_assignment_tenures.includes(:assignment).to_a

      @energy_by_assignment_chart = []
      @total_energy_percentage = 0
      tenures.each do |tenure|
        energy = inflight_energy_for(tenure)
        @total_energy_percentage += energy
        next if energy <= 0

        @energy_by_assignment_chart << {
          name: tenure.assignment.title,
          y: energy
        }
      end

      @alert_band = alert_band_for(@total_energy_percentage)
      @energy_by_rating_chart = build_official_rating_chart(tenures)
      @energy_by_inflight_rating_chart = build_inflight_rating_chart(tenures)
      @show_inflight_rating_chart = chart_data_present?
      self
    end

    def chart_data_present?
      energy_by_assignment_chart.any?
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

    def inflight_energy_for(tenure)
      open = open_check_in_for(tenure)
      if open&.employee_completed? && !open.actual_energy_percentage.nil?
        open.actual_energy_percentage.to_i
      else
        tenure.anticipated_energy_percentage.to_i
      end
    end

    def inflight_rating_for(tenure)
      open = open_check_in_for(tenure)
      if open&.manager_completed? && open.manager_rating.present?
        open.manager_rating
      else
        tenure.official_rating
      end
    end

    def build_official_rating_chart(tenures)
      buckets = RATING_BUCKETS.keys.index_with { 0 }

      tenures.each do |tenure|
        energy = tenure.anticipated_energy_percentage.to_i
        next if energy <= 0

        check_in = @latest_finalized_check_ins_by_assignment_id[tenure.assignment_id]
        rating = check_in&.official_rating
        key = RATING_BUCKETS.key?(rating) ? rating : 'no_check_in'
        buckets[key] += energy
      end

      chart_points_from_buckets(buckets)
    end

    def build_inflight_rating_chart(tenures)
      buckets = RATING_BUCKETS.keys.index_with { 0 }

      tenures.each do |tenure|
        energy = inflight_energy_for(tenure)
        next if energy <= 0

        rating = inflight_rating_for(tenure)
        key = RATING_BUCKETS.key?(rating) ? rating : 'no_check_in'
        buckets[key] += energy
      end

      chart_points_from_buckets(buckets, no_rating_label: INFLIGHT_NO_RATING_LABEL)
    end

    def chart_points_from_buckets(buckets, no_rating_label: nil)
      RATING_BUCKETS.filter_map do |key, meta|
        energy = buckets[key]
        next if energy.zero?

        label = key == 'no_check_in' && no_rating_label.present? ? no_rating_label : meta[:label]
        { name: label, y: energy, color: meta[:color] }
      end
    end
  end
end
