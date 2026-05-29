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
                :energy_by_rating_chart

    def self.build(teammate:, latest_finalized_check_ins_by_assignment_id:)
      new(
        teammate: teammate,
        latest_finalized_check_ins_by_assignment_id: latest_finalized_check_ins_by_assignment_id
      ).tap(&:compute!)
    end

    def self.for_teammate(teammate, organization: teammate.organization)
      assignment_ids = teammate.active_assignment_tenures.pluck(:assignment_id)
      latest_finalized_check_ins_by_assignment_id = {}
      if assignment_ids.any?
        AssignmentCheckIn
          .where(company_teammate: teammate, assignment_id: assignment_ids)
          .closed
          .includes(:assignment, manager_completed_by_teammate: :person, finalized_by_teammate: :person)
          .order(official_check_in_completed_at: :desc)
          .each do |check_in|
            latest_finalized_check_ins_by_assignment_id[check_in.assignment_id] ||= check_in
          end
      end

      build(
        teammate: teammate,
        latest_finalized_check_ins_by_assignment_id: latest_finalized_check_ins_by_assignment_id
      )
    end

    def initialize(teammate:, latest_finalized_check_ins_by_assignment_id:)
      @teammate = teammate
      @latest_finalized_check_ins_by_assignment_id = latest_finalized_check_ins_by_assignment_id || {}
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

    def build_rating_chart(tenures)
      buckets = RATING_BUCKETS.keys.index_with { 0 }

      tenures.each do |tenure|
        check_in = @latest_finalized_check_ins_by_assignment_id[tenure.assignment_id]
        rating = check_in&.official_rating
        key = RATING_BUCKETS.key?(rating) ? rating : 'no_check_in'
        buckets[key] += tenure.anticipated_energy_percentage.to_i
      end

      RATING_BUCKETS.filter_map do |key, meta|
        energy = buckets[key]
        next if energy.zero?

        { name: meta[:label], y: energy, color: meta[:color] }
      end
    end
  end
end
