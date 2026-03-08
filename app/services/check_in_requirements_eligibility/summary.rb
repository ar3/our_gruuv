# frozen_string_literal: true

module CheckInRequirementsEligibility
  # Display status for the exceed/meet percentage lines.
  module DisplayStatus
    OK = :ok           # ✅ (first % >= threshold)
    MAYBE_OK = :maybe_ok # ⁉️✅ (second % >= threshold but first < threshold)
    NOT_MET = :not_met   # 🚧
  end

  # Immutable summary: counts by category, percentages, and eligibility.
  class Summary
    attr_reader :count_unknown, :count_miss, :count_maybe_meeting, :count_meeting,
                :count_maybe_exceeding, :count_exceeding,
                :total,
                :full_exceed_pct, :exceed_plus_maybe_exceed_pct,
                :full_meet_pct, :meet_plus_maybe_meet_pct,
                :meeting_threshold_pct, :exceeding_threshold_pct,
                :exceed_display_status, :meet_display_status,
                :overall_eligible

    def initialize(
      count_unknown: 0, count_miss: 0, count_maybe_meeting: 0, count_meeting: 0,
      count_maybe_exceeding: 0, count_exceeding: 0,
      meeting_threshold_pct: nil, exceeding_threshold_pct: nil
    )
      @count_unknown = count_unknown
      @count_miss = count_miss
      @count_maybe_meeting = count_maybe_meeting
      @count_meeting = count_meeting
      @count_maybe_exceeding = count_maybe_exceeding
      @count_exceeding = count_exceeding
      @total = count_unknown + count_miss + count_maybe_meeting + count_meeting + count_maybe_exceeding + count_exceeding
      @meeting_threshold_pct = meeting_threshold_pct
      @exceeding_threshold_pct = exceeding_threshold_pct

      if @total.positive?
        @full_exceed_pct = (count_exceeding.to_f / @total * 100).round(1)
        @exceed_plus_maybe_exceed_pct = ((count_exceeding + count_maybe_exceeding).to_f / @total * 100).round(1)
        # Full meet = Exceeding + Maybe Exceeding + Meeting; Meet (maybe) = + Maybe Meeting
        count_full_meet = count_exceeding + count_maybe_exceeding + count_meeting
        count_meet_plus_maybe = count_exceeding + count_maybe_exceeding + count_meeting + count_maybe_meeting
        @full_meet_pct = (count_full_meet.to_f / @total * 100).round(1)
        @meet_plus_maybe_meet_pct = (count_meet_plus_maybe.to_f / @total * 100).round(1)
      else
        @full_exceed_pct = 0.0
        @exceed_plus_maybe_exceed_pct = 0.0
        @full_meet_pct = 0.0
        @meet_plus_maybe_meet_pct = 0.0
      end

      @exceed_display_status = compute_display_status(@full_exceed_pct, @exceed_plus_maybe_exceed_pct, exceeding_threshold_pct)
      @meet_display_status = compute_display_status(@full_meet_pct, @meet_plus_maybe_meet_pct, meeting_threshold_pct)

      @overall_eligible = compute_overall_eligible
    end

    def exceed_status_icon
      case exceed_display_status
      when DisplayStatus::OK then "✅"
      when DisplayStatus::MAYBE_OK then "⁉️✅"
      else "🚧"
      end
    end

    def meet_status_icon
      case meet_display_status
      when DisplayStatus::OK then "✅"
      when DisplayStatus::MAYBE_OK then "⁉️✅"
      else "🚧"
      end
    end

    private

    def compute_display_status(first_pct, second_pct, threshold)
      return DisplayStatus::NOT_MET if threshold.blank? || threshold <= 0
      return DisplayStatus::OK if first_pct >= threshold
      return DisplayStatus::MAYBE_OK if second_pct >= threshold
      DisplayStatus::NOT_MET
    end

    def compute_overall_eligible
      meet_ok = meeting_threshold_pct.blank? || meeting_threshold_pct <= 0 ||
                meet_plus_maybe_meet_pct >= meeting_threshold_pct
      exceed_ok = exceeding_threshold_pct.blank? || exceeding_threshold_pct <= 0 ||
                  exceed_plus_maybe_exceed_pct >= exceeding_threshold_pct
      meet_ok && exceed_ok
    end
  end
end
