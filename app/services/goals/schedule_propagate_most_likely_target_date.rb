# frozen_string_literal: true

module Goals
  # Call after a Goal has been successfully persisted when +most_likely_target_date+ may have changed.
  # Only applies to updates (not first insert): new goals have no children to propagate to.
  # Runs {Goals::PropagateMostLikelyTargetDateJob} synchronously; does nothing if that attribute did not change on last save.
  class SchedulePropagateMostLikelyTargetDate
    def self.call(goal)
      return if goal.previously_new_record?
      return unless goal.saved_change_to_most_likely_target_date?

      PropagateMostLikelyTargetDateJob.perform_now(goal.id)
    end
  end
end
