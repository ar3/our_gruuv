# frozen_string_literal: true

module CheckInRequirementsEligibility
  # Immutable result for one row (one aspiration or assignment).
  class RowResult
    attr_reader :row_id, :category, :label

    def initialize(row_id:, category:, label: nil)
      @row_id = row_id
      @category = category
      @label = label || RowCategory.label(category)
    end

    def unknown? = category == RowCategory::UNKNOWN
    def miss? = category == RowCategory::MISS
    def maybe_meeting? = category == RowCategory::MAYBE_MEETING
    def meeting? = category == RowCategory::MEETING
    def maybe_exceeding? = category == RowCategory::MAYBE_EXCEEDING
    def exceeding? = category == RowCategory::EXCEEDING
  end
end
