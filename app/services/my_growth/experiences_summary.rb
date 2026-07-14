# frozen_string_literal: true

module MyGrowth
  # Energy total, alert band, and Highcharts pie payloads for My Growth > Experiences summary.
  class ExperiencesSummary
    RATING_BUCKETS = {
      'working_to_meet' => { label: 'Working to Meet expectations', color: '#ffc107' },
      'meeting' => { label: 'Meeting expectations', color: '#0d6efd' },
      'exceeding' => { label: 'Exceeding Expectations', color: '#198754' },
      'no_check_in' => { label: 'No finalized check-in', color: '#6c757d' }
    }.freeze

    attr_reader :total_energy_percentage,
                :alert_band,
                :energy_by_assignment_chart,
                :energy_by_rating_chart,
                :energy_by_inflight_viewer_rating_chart,
                :show_inflight_viewer_rating_chart

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
      @viewer_teammate = viewer_teammate
      @open_check_ins_by_assignment_id = open_check_ins_by_assignment_id || {}
      @show_inflight_viewer_rating_chart = false
    end

    def compute!
      tenures = @teammate.active_assignment_tenures.includes(:assignment).to_a
      @total_energy_percentage = tenures.sum { |t| t.anticipated_energy_percentage.to_i }
      @alert_band = alert_band_for(@total_energy_percentage)
      @energy_by_assignment_chart = tenures.map do |tenure|
        {
          name: tenure.assignment.title,
          y: tenure.anticipated_energy_percentage.to_i
        }
      end
      @energy_by_rating_chart = build_rating_chart(tenures)
      @energy_by_inflight_viewer_rating_chart = build_inflight_viewer_rating_chart(tenures)
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

    def viewer_perspective
      return nil if @viewer_teammate.blank?
      return :employee if @viewer_teammate.id == @teammate.id
      return :manager if @viewer_teammate.in_managerial_hierarchy_of?(@teammate)

      nil
    end

    def viewer_completed_open_side?(check_in, perspective)
      return false if check_in.blank? || !check_in.open?

      case perspective
      when :employee then check_in.employee_completed?
      when :manager then check_in.manager_completed?
      else false
      end
    end

    def viewer_open_rating(check_in, perspective)
      case perspective
      when :employee then check_in.employee_rating
      when :manager then check_in.manager_rating
      end
    end

    def build_rating_chart(tenures)
      buckets = RATING_BUCKETS.keys.index_with { 0 }

      tenures.each do |tenure|
        check_in = @latest_finalized_check_ins_by_assignment_id[tenure.assignment_id]
        rating = check_in&.official_rating
        key = RATING_BUCKETS.key?(rating) ? rating : 'no_check_in'
        buckets[key] += tenure.anticipated_energy_percentage.to_i
      end

      chart_points_from_buckets(buckets)
    end

    # Same active-tenure energy set as the finalized rating chart, but assignments where the
    # viewer completed their open (unfinalized) side use the viewer's rating instead.
    def build_inflight_viewer_rating_chart(tenures)
      perspective = viewer_perspective
      return [] if perspective.blank?

      swapped_any = false
      buckets = RATING_BUCKETS.keys.index_with { 0 }

      tenures.each do |tenure|
        open_check_in = @open_check_ins_by_assignment_id[tenure.assignment_id]
        energy = tenure.anticipated_energy_percentage.to_i

        if viewer_completed_open_side?(open_check_in, perspective)
          swapped_any = true
          rating = viewer_open_rating(open_check_in, perspective)
        else
          rating = @latest_finalized_check_ins_by_assignment_id[tenure.assignment_id]&.official_rating
        end

        key = RATING_BUCKETS.key?(rating) ? rating : 'no_check_in'
        buckets[key] += energy
      end

      @show_inflight_viewer_rating_chart = swapped_any
      return [] unless swapped_any

      chart_points_from_buckets(buckets)
    end

    def chart_points_from_buckets(buckets)
      RATING_BUCKETS.filter_map do |key, meta|
        energy = buckets[key]
        next if energy.zero?

        { name: meta[:label], y: energy, color: meta[:color] }
      end
    end
  end
end
