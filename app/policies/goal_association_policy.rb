class GoalAssociationPolicy < ApplicationPolicy
  def create?
    return false unless record&.associable && record&.goal
    return true if admin_bypass?

    if (tid = record.goal_flow_teammate_id).present?
      subject_teammate = CompanyTeammate.find_by(id: tid)
      return false unless subject_teammate && GoalFlowTeammateScope.teammate_matches_associable?(record.associable, subject_teammate)

      # Self, managerial chain, or employment management — same as who may audit that teammate.
      Pundit.policy!(pundit_user, subject_teammate).audit?
    else
      policy_for_associable.update?
    end
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
