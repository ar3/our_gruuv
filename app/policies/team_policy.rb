class TeamPolicy < ApplicationPolicy
  def index?
    admin_bypass? || true # Anyone can view teams list
  end

  def show?
    admin_bypass? || team_in_company?
  end

  def create?
    return false unless viewing_teammate
    return false unless team_in_company?
    admin_bypass? || viewing_teammate.can_manage_departments_and_teams?
  end

  def update?
    return false unless viewing_teammate
    return false unless team_in_company?
    admin_bypass? || viewing_teammate.can_manage_departments_and_teams? || viewing_teammate_is_team_member?
  end

  def archive?
    return false unless viewing_teammate
    return false unless team_in_company?
    admin_bypass? || viewing_teammate.can_manage_departments_and_teams?
  end

  def destroy?
    # Destroy is disabled - use archive instead
    false
  end

  def manage_members?
    update?
  end

  def update_members?
    update?
  end

  private

  def team_in_company?
    return false unless viewing_teammate
    # Class-level policy check (e.g. policy(Team).show? in layout) — allow when in an org
    return true if record.is_a?(Class)
    return true if record.new_record? # Allow new records
    record.company_id == viewing_teammate.organization_id
  end

  def viewing_teammate_is_team_member?
    return false unless viewing_teammate && record.persisted?
    record.team_members.exists?(company_teammate_id: viewing_teammate.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      
      if admin_bypass?
        scope.all
      else
        scope.for_company(viewing_teammate.organization)
      end
    end
  end
end
