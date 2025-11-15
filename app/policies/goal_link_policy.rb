class GoalLinkPolicy < ApplicationPolicy
  def create?
    admin_bypass? || can_edit_this_goal?
  end

  def destroy?
    admin_bypass? || can_edit_this_goal?
  end

  private

  def can_edit_this_goal?
    return false unless record&.parent
    return false unless teammate
    
    GoalPolicy.new(pundit_user, record.parent).update?
  end
end









