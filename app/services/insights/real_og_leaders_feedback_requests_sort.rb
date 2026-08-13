# frozen_string_literal: true

module Insights
  # Shared sort for Feedback requests board on Real OG Leaders.
  # Order:
  # 1. More criteria met (4 → 3 → 2 → 1)
  # 2. Among the same count, prefer subject → requestor → respondent → completed
  #    (bitmask: subject=8, requestor=4, respondent=2, completed=1; higher first)
  # 3. Most recent activity first
  # 4. Display name
  module RealOgLeadersFeedbackRequestsSort
    module_function

    def sort_key(entry)
      has_subject = entry.has_requested_about
      has_requestor = entry.has_sent
      has_respondent = entry.has_received
      has_completed = entry.has_completed
      signal_count = [has_subject, has_requestor, has_respondent, has_completed].count(true)

      [
        -signal_count,
        -combination_bitmask(has_subject, has_requestor, has_respondent, has_completed),
        -(entry.most_recent_at&.to_i || 0),
        entry.display_name.to_s.downcase
      ]
    end

    def combination_bitmask(has_subject, has_requestor, has_respondent, has_completed)
      (has_subject ? 8 : 0) |
        (has_requestor ? 4 : 0) |
        (has_respondent ? 2 : 0) |
        (has_completed ? 1 : 0)
    end
  end
end
