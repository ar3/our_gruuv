# frozen_string_literal: true

module CheckIns
  # Shared ordering for "which required check-in needs attention most":
  # 1. Clarity severity (obscured, then blurred, then clear, then crystal_clear)
  # 2. Official rating: working_to_meet before others (matches check-in health UX)
  # 3. Type: aspiration, then assignment, then position
  # 4. Stale finalized time ascending (oldest / never finalized first)
  module RequiredCheckInUrgencySort
    CLARITY_SEVERITY = {
      obscured: 0,
      blurred: 1,
      clear: 2,
      crystal_clear: 3
    }.freeze

    TYPE_ORDER = {
      aspiration: 0,
      assignment: 1,
      position: 2
    }.freeze

    module_function

    def sort_tuple(clarity_level, kind, finalized_at, official_rating = nil)
      clarity_sym = clarity_level.to_s.presence&.to_sym || :obscured
      severity = CLARITY_SEVERITY.fetch(clarity_sym, CLARITY_SEVERITY[:obscured])
      rating_rank = official_rating.to_s == "working_to_meet" ? 0 : 1
      kind_sym = kind.to_s.presence&.to_sym || :assignment
      type_rank = TYPE_ORDER.fetch(kind_sym, 99)
      stale_key = finalized_at.present? ? finalized_at.to_time.to_i : 0
      [severity, rating_rank, type_rank, stale_key]
    end

    def parse_iso8601(time_string)
      return nil if time_string.blank?

      Time.zone.parse(time_string.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
