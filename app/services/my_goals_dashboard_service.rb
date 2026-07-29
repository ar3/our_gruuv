# frozen_string_literal: true

# Summarizes owned goals for the Start Here "My Goals" widget using Gruuv Health Goal Confidence.
class MyGoalsDashboardService
  def initialize(teammate:)
    @teammate = teammate
  end

  # with_recent_check_in: scored goals with EH Healthy status
  # without_recent_check_in: scored goals with Warning or Needs Attention
  # draft: not deleted, not completed, not started
  # completed: not deleted, completed_at present (Goal.completed)
  def counts
    return empty_counts unless @teammate

    base = Goal.where(owner: @teammate, deleted_at: nil)
    draft_count = base.where(completed_at: nil, started_at: nil).count
    completed_count = base.completed.count

    records = GoalsHealthEngagementHealthSupport.records_by_teammate_id(
      organization: @teammate.organization,
      teammate_ids: [@teammate.id]
    )[@teammate.id] || []
    items = GoalsHealthEngagementHealthSupport.items_for(records)
    healthy = items.count { |item| item.status == EngagementHealth::HEALTHY }
    not_healthy = items.count { |item| item.status != EngagementHealth::HEALTHY }

    {
      with_recent_check_in: healthy,
      without_recent_check_in: not_healthy,
      draft: draft_count,
      completed: completed_count
    }
  end

  private

  def empty_counts
    { with_recent_check_in: 0, without_recent_check_in: 0, draft: 0, completed: 0 }
  end
end
