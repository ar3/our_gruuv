# frozen_string_literal: true

module CheckIns
  module SlackOgoConsult
    # Same bar as Include default on the Slack review page (and LLM include threshold).
    CONFIDENCE_THRESHOLD = Llm::SlackMomentsExtractor::INCLUDE_CONFIDENCE_THRESHOLD
    # Show prior results even when older; warn when past this age.
    STALE_AFTER = 7.days
    REFRESH_SEARCH_AFTER = 3.days
    # Default when no prior finalized check-in / milestone (first check-in for object).
    DEFAULT_FIRST_CHECK_IN_WINDOW_DAYS = 30
    # Legacy constant — prefer WindowDays.call(since:).
    WINDOW_DAYS = DEFAULT_FIRST_CHECK_IN_WINDOW_DAYS
    RATEABLE_TYPES = %w[Assignment Ability Aspiration].freeze

    module_function

    def rateable_type_valid?(type)
      RATEABLE_TYPES.include?(type.to_s)
    end
  end
end
