# frozen_string_literal: true

class TeamAsanaLinkPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return false unless record.team

    # Can view if can view the team (team member or org member with team access)
    TeamPolicy.new(pundit_user, record.team).show?
  end

  def update?
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return false unless record.team

    # Can update team Asana link if can update the team (manage departments/teams or team member)
    TeamPolicy.new(pundit_user, record.team).update?
  end

  def create?
    update?
  end
end
