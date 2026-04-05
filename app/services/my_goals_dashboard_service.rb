# frozen_string_literal: true

# Summarizes owned goals for the Start Here "My Goals" widget (same 14-day / Monday cutoff as About Me goals status).
class MyGoalsDashboardService
  def initialize(teammate:)
    @teammate = teammate
  end

  # with_recent_check_in: active goals with at least one check-in in the rolling window
  # without_recent_check_in: active goals with none in that window
  # draft: not deleted, not completed, not started
  # completed: not deleted, completed_at present (Goal.completed)
  def counts
    return empty_counts unless @teammate

    base = Goal.where(owner: @teammate, deleted_at: nil)
    draft_count = base.where(completed_at: nil, started_at: nil).count
    completed_count = base.completed.count

    active_ids = base.active.pluck(:id)
    if active_ids.empty?
      return {
        with_recent_check_in: 0,
        without_recent_check_in: 0,
        draft: draft_count,
        completed: completed_count
      }
    end

    cutoff_week = (Date.current - 14.days).beginning_of_week(:monday)
    with_recent = GoalCheckIn
      .where(goal_id: active_ids)
      .where("check_in_week_start >= ?", cutoff_week)
      .distinct
      .count(:goal_id)

    {
      with_recent_check_in: with_recent,
      without_recent_check_in: active_ids.size - with_recent,
      draft: draft_count,
      completed: completed_count
    }
  end

  private

  def empty_counts
    { with_recent_check_in: 0, without_recent_check_in: 0, draft: 0, completed: 0 }
  end
end
