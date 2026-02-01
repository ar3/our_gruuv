class DepartmentPolicy < ApplicationPolicy
  def show?
    # All authenticated users can view departments
    true
  end

  def create?
    admin_bypass? || user_can_manage_departments?
  end

  def update?
    admin_bypass? || user_can_manage_departments?
  end

  def archive?
    admin_bypass? || user_can_manage_departments?
  end

  def destroy?
    admin_bypass? || user_can_manage_departments?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      return scope.all if person&.og_admin?
      
      viewing_teammate_org = viewing_teammate.organization
      return scope.none unless viewing_teammate_org
      
      # Get the company for this organization
      company = viewing_teammate_org.company? ? viewing_teammate_org : viewing_teammate_org.root_company
      return scope.none unless company
      
      scope.where(company_id: company.id)
    end
  end

  private

  def user_can_manage_departments?
    return false unless viewing_teammate
    viewing_teammate.can_manage_departments_and_teams?
  end
end
