module Goals
  class PropagateMostLikelyTargetDateJob < ApplicationJob
    def perform(goal_id)
      goal = Goal.find_by(id: goal_id)
      return if goal.blank?

      parent_date = goal.most_likely_target_date

      goal.linked_goals
        .where(started_at: nil, deleted_at: nil, completed_at: nil)
        .where(company_id: goal.company_id)
        .find_each do |child|
          child.sync_most_likely_target_date!(parent_date)
          child.save!
          Goals::SchedulePropagateMostLikelyTargetDate.call(child)
        end
    end
  end
end
