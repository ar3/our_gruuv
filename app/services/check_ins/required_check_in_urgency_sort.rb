# frozen_string_literal: true

module CheckIns
  # Shared ordering for "which required check-in needs attention most":
  # 1. Gruuv Health Required Clarity severity (Needs Attention, then Warning, then Healthy)
  # 2. Official rating: working_to_meet before others (matches check-in health UX)
  # 3. Type: aspiration, then assignment, then position
  # 4. Stale finalized time ascending (oldest / never finalized first)
  module RequiredCheckInUrgencySort
    TYPE_ORDER = {
      aspiration: 0,
      assignment: 1,
      position: 2
    }.freeze

    module_function

    def sort_tuple(status, kind, finalized_at, official_rating = nil)
      status_sym = normalize_status(status)
      severity = EngagementHealth.status_severity_rank(status_sym)
      rating_rank = official_rating.to_s == "working_to_meet" ? 0 : 1
      kind_sym = kind.to_s.presence&.to_sym || :assignment
      type_rank = TYPE_ORDER.fetch(kind_sym, 99)
      stale_key = finalized_at.present? ? finalized_at.to_time.to_i : 0
      [severity, rating_rank, type_rank, stale_key]
    end

    def normalize_status(status)
      case status.to_s.presence&.to_sym
      when :needs_attention, :obscured
        EngagementHealth::NEEDS_ATTENTION
      when :warning, :blurred
        EngagementHealth::WARNING
      when :healthy, :clear, :crystal_clear
        EngagementHealth::HEALTHY
      else
        EngagementHealth::NEEDS_ATTENTION
      end
    end

    def parse_iso8601(time_string)
      return nil if time_string.blank?

      Time.zone.parse(time_string.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
