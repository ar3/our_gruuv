# frozen_string_literal: true

module CheckInRequirementsEligibility
  # Strongly-typed result of the calculator: row results and summary.
  class CalculatorResult
    attr_reader :row_results, :summary

    def initialize(row_results:, summary:)
      @row_results = row_results
      @summary = summary
    end

    def row_result_by_id(row_id)
      row_results.find { |r| r.row_id == row_id }
    end
  end
end
