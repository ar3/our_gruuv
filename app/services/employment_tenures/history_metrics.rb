# frozen_string_literal: true

module EmploymentTenures
  # Derived employment-history readouts for the correct-history page.
  class HistoryMetrics
    Stretch = Data.define(:started_at, :ended_at, :duration_seconds, :open?)
    Gap = Data.define(:earlier_tenure_id, :later_tenure_id, :gap_started_at, :gap_ended_at)

    def self.call(tenures:)
      new(tenures: tenures).call
    end

    def initialize(tenures:)
      @tenures = Array(tenures)
    end

    def call
      sorted = @tenures.sort_by(&:started_at)
      stretches = consecutive_stretches(sorted)
      gaps = detect_gaps(sorted)

      {
        sorted_tenures: sorted,
        total_employed_seconds: stretches.sum(&:duration_seconds),
        last_promotion_at: last_promotion(sorted)&.started_at,
        last_promotion_position_name: last_promotion(sorted)&.position&.display_name,
        boomerang_count: [stretches.length - 1, 0].max,
        consecutive_stretches: stretches,
        position_change_count: adjacent_change_count(sorted, :position_id),
        managerial_change_count: adjacent_change_count(sorted, :manager_teammate_id),
        gaps: gaps
      }
    end

    private

    def consecutive_stretches(sorted)
      return [] if sorted.empty?

      stretches = []
      stretch_start = sorted.first.started_at
      stretch_end = sorted.first.ended_at
      open = sorted.first.ended_at.nil?

      sorted.drop(1).each do |tenure|
        if open || contiguous?(stretch_end, tenure.started_at)
          if tenure.ended_at.nil?
            stretch_end = nil
            open = true
          elsif stretch_end.nil? || tenure.ended_at > stretch_end
            stretch_end = tenure.ended_at unless open
          end
        else
          stretches << build_stretch(stretch_start, stretch_end, open)
          stretch_start = tenure.started_at
          stretch_end = tenure.ended_at
          open = tenure.ended_at.nil?
        end
      end

      stretches << build_stretch(stretch_start, stretch_end, open)
      stretches
    end

    def build_stretch(started_at, ended_at, open)
      end_time = open || ended_at.nil? ? Time.current : ended_at
      duration = [end_time.to_i - started_at.to_i, 0].max
      Stretch.new(
        started_at: started_at,
        ended_at: open ? nil : ended_at,
        duration_seconds: duration,
        open?: open
      )
    end

    def detect_gaps(sorted)
      gaps = []
      sorted.each_cons(2) do |earlier, later|
        next if earlier.ended_at.nil?
        next if contiguous?(earlier.ended_at, later.started_at)

        gaps << Gap.new(
          earlier_tenure_id: earlier.id,
          later_tenure_id: later.id,
          gap_started_at: earlier.ended_at,
          gap_ended_at: later.started_at
        )
      end
      gaps
    end

    # Same calendar day (or later start on/before earlier end) counts as continuous employment.
    def contiguous?(earlier_end, later_start)
      return false if earlier_end.nil?

      later_start.to_date <= earlier_end.to_date
    end

    def last_promotion(sorted)
      previous = nil
      last = nil
      sorted.each do |tenure|
        if previous && tenure.position_id != previous.position_id
          last = tenure
        end
        previous = tenure
      end
      last
    end

    def adjacent_change_count(sorted, attribute)
      count = 0
      sorted.each_cons(2) do |a, b|
        count += 1 if a.public_send(attribute) != b.public_send(attribute)
      end
      count
    end
  end
end
