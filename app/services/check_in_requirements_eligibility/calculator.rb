# frozen_string_literal: true

module CheckInRequirementsEligibility
  # Computes row categories and summary for check-in requirements (3-level: working to meet, meeting, exceeding).
  # Uses timeframe (minimum_months) and thresholds for meeting/exceeding percentages.
  class Calculator
    def initialize(
      row_ids:,
      monthly_statuses_by_row_id:,
      minimum_months:,
      meeting_threshold_pct: nil,
      exceeding_threshold_pct: nil
    )
      @row_ids = Array(row_ids)
      @monthly_statuses_by_row_id = monthly_statuses_by_row_id || {}
      @minimum_months = minimum_months.to_i
      @meeting_threshold_pct = meeting_threshold_pct.presence&.to_f
      @exceeding_threshold_pct = exceeding_threshold_pct.presence&.to_f
    end

    def call
      row_results = @row_ids.map { |id| row_result_for(id) }
      summary = build_summary(row_results)
      CalculatorResult.new(row_results: row_results, summary: summary)
    end

    private

    def row_result_for(row_id)
      monthly = @monthly_statuses_by_row_id[row_id] || []
      category = categorize_row(monthly)
      RowResult.new(row_id: row_id, category: category)
    end

    # Uses last minimum_months of the 12-month window for categorization.
    def months_in_range(monthly)
      return [] if monthly.blank?
      n = [@minimum_months, monthly.size].min
      n <= 0 ? monthly : monthly.last(n)
    end

    def categorize_row(monthly)
      in_range = months_in_range(monthly)
      statuses = in_range.map { |c| (c[:status] || c["status"]).to_sym }

      return RowCategory::UNKNOWN if statuses.all? { |s| s == :none }
      return RowCategory::MISS if statuses.any? { |s| s == :working_to_meet }
      return RowCategory::EXCEEDING if statuses.size >= 1 && statuses.all? { |s| s == :exceeding }
      if statuses.any? { |s| s == :exceeding } && statuses.none? { |s| s == :working_to_meet }
        return RowCategory::MAYBE_EXCEEDING
      end
      # All months in range meeting = Meeting. Some none + some meeting = Maybe Meeting (uncertain due to gaps).
      return RowCategory::MEETING if statuses.size >= 1 && statuses.all? { |s| s == :meeting }
      return RowCategory::MAYBE_MEETING if statuses.any? { |s| s == :none } && statuses.any? { |s| s == :meeting } &&
                                          statuses.none? { |s| s == :working_to_meet } && statuses.none? { |s| s == :exceeding }

      # Fallback: has meeting and/or none, no working_to_meet (e.g. mix of meeting + exceeding without meeting+none)
      if statuses.any? { |s| s == :meeting } && statuses.none? { |s| s == :working_to_meet }
        return RowCategory::MAYBE_MEETING
      end
      RowCategory::UNKNOWN
    end

    def build_summary(row_results)
      counts = Hash.new(0)
      row_results.each { |r| counts[r.category] += 1 }
      Summary.new(
        count_unknown: counts[RowCategory::UNKNOWN],
        count_miss: counts[RowCategory::MISS],
        count_maybe_meeting: counts[RowCategory::MAYBE_MEETING],
        count_meeting: counts[RowCategory::MEETING],
        count_maybe_exceeding: counts[RowCategory::MAYBE_EXCEEDING],
        count_exceeding: counts[RowCategory::EXCEEDING],
        meeting_threshold_pct: @meeting_threshold_pct,
        exceeding_threshold_pct: @exceeding_threshold_pct
      )
    end
  end
end
