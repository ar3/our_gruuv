# frozen_string_literal: true

module CheckInRequirementsEligibility
  # Strongly-typed row category. Order matters for display/sorting.
  module RowCategory
    UNKNOWN = :unknown
    MISS = :miss
    MAYBE_MEETING = :maybe_meeting
    MEETING = :meeting
    MAYBE_EXCEEDING = :maybe_exceeding
    EXCEEDING = :exceeding

    ALL = [UNKNOWN, MISS, MAYBE_MEETING, MEETING, MAYBE_EXCEEDING, EXCEEDING].freeze

    LABELS = {
      UNKNOWN => "Unknown ⁉️",
      MISS => "Miss ❌",
      MAYBE_MEETING => "Maybe Meeting ❔👍",
      MEETING => "Meeting 👍",
      MAYBE_EXCEEDING => "Maybe Exceeding ❔🎉",
      EXCEEDING => "Exceeding 🎉"
    }.freeze

    def self.label(category)
      LABELS[category] || category.to_s.humanize
    end
  end
end
