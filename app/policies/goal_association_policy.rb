class GoalAssociationPolicy < ApplicationPolicy
  def create?
    return false unless record&.associable && record&.goal
    return true if admin_bypass?

    policy_for_associable.update?
  end

  def destroy?
    create?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  private

  def policy_for_associable
    Pundit.policy!(pundit_user, record.associable)
  end
end
