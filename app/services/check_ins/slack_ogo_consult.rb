# frozen_string_literal: true

module CheckIns
  module SlackOgoConsult
    CONFIDENCE_THRESHOLD = 0.80
    # Show prior results even when older; warn when past this age.
    STALE_AFTER = 7.days
    REFRESH_SEARCH_AFTER = 3.days
    WINDOW_DAYS = 90
    RATEABLE_TYPES = %w[Assignment Ability Aspiration].freeze

    module_function

    def rateable_type_valid?(type)
      RATEABLE_TYPES.include?(type.to_s)
    end
  end
end
