class GoalCheckInPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    admin_bypass? || goal_policy.show?
  end

  def create?
    return false unless viewing_teammate
    admin_bypass? || goal_policy.show?
  end

  def update?
    return false unless viewing_teammate
    admin_bypass? || goal_policy.show?
  end

  def destroy?
    return false unless viewing_teammate
    admin_bypass? || goal_policy.show?
  end

  private

  def goal_policy
    @goal_policy ||= GoalPolicy.new(pundit_user, record.goal)
  end
end


