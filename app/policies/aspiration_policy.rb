class AspirationPolicy < ApplicationPolicy
  def show?
    # Allow all authenticated users to view individual aspirations
    true
  end

  def create?
    admin_bypass? || user_has_maap_permission?
  end

  def update?
    admin_bypass? || user_has_maap_permission_for_record?
  end

  def destroy?
    admin_bypass? || user_has_maap_permission_for_record?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person.og_admin?
        scope.all
      else
        viewing_teammate_org = viewing_teammate.organization
        return scope.none unless viewing_teammate_org
        
        # Get the company for the viewing teammate's organization
        company = viewing_teammate_org.company? ? viewing_teammate_org : viewing_teammate_org.root_company
        scope.where(company_id: company&.id)
      end
    end
  end

  private

  def user_has_maap_permission?
    return false unless viewing_teammate
    return false unless actual_organization
    
    viewing_teammate.can_manage_maap?
  end

  def user_has_maap_permission_for_record?
    return false unless viewing_teammate
    return false unless record&.company
    viewing_teammate_org = viewing_teammate.organization
    return false unless viewing_teammate_org
    
    # Check if record's company matches viewing_teammate's company
    company = viewing_teammate_org.company? ? viewing_teammate_org : viewing_teammate_org.root_company
    return false unless company&.id == record.company_id
    
    viewing_teammate.can_manage_maap?
  end
end
