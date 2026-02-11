class GoalCheckInPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    admin_bypass? || goal_policy.show?
  end

  def create?
    return false unless viewing_teammate
    admin_bypass? || can_add_check_in?
  end

  def update?
    return false unless viewing_teammate
    admin_bypass? || can_add_check_in?
  end

  def destroy?
    return false unless viewing_teammate
    admin_bypass? || goal_policy.show?
  end

  private

  def goal_policy
    @goal_policy ||= GoalPolicy.new(pundit_user, record.goal)
  end

  # Teammate-owned goals: only creator or owner can add check-ins.
  # Team/department/company goals: if you can see the goal, you can add a check-in.
  def can_add_check_in?
    goal = record.goal
    if goal.owner_type == 'CompanyTeammate'
      goal_policy.update?
    else
      goal_policy.show?
    end
  end
end


