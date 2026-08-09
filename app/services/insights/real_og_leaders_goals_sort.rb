# frozen_string_literal: true

module Insights
  # Shared sort for personal and shared Goals boards on Real OG Leaders.
  # Order:
  # 1. More criteria met (3 → 2 → 1)
  # 2. Among the same count, prefer confidence, then connected, then completed
  #    (pairs: conf+connected → conf+completed → connected+completed;
  #     singles: conf → connected → completed)
  # 3. Most recent confidence check (nil / never checked last within group)
  # 4. Display name
  module RealOgLeadersGoalsSort
    module_function

    def sort_key(entry)
      has_c = entry.has_confidence_check
      has_conn = entry.has_connection
      has_comp = entry.has_completion
      signal_count = [has_c, has_conn, has_comp].count(true)

      [
        -signal_count,
        combination_rank(has_c, has_conn, has_comp),
        -(entry.latest_confidence_check_at&.to_i || 0),
        entry.display_name.to_s.downcase
      ]
    end

    # Lower is better within the same signal count.
    def combination_rank(has_confidence, has_connection, has_completion)
      case [has_confidence, has_connection, has_completion].count(true)
      when 3
        0
      when 2
        return 0 if has_confidence && has_connection
        return 1 if has_confidence && has_completion
        2 # connection + completion
      when 1
        return 0 if has_confidence
        return 1 if has_connection
        2 # completion only
      else
        9
      end
    end
  end
end
