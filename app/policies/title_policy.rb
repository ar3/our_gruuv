class TitlePolicy < ApplicationPolicy
  def show?
    admin_bypass? || user_has_maap_permission_for_record? || user_is_active_company_teammate_in_same_company?
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

  def clone_positions?
    admin_bypass? || user_has_maap_permission_for_record?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person&.og_admin?
        scope.all
      else
        viewing_teammate_org = viewing_teammate.organization
        return scope.none unless viewing_teammate_org
        
        # Get root company for viewing teammate
        root_company = viewing_teammate_org.root_company
        return scope.none unless root_company
        
        # Include titles if:
        # 1. User can manage MAAP (existing behavior)
        # 2. User is actively employed company teammate in the same company
        if viewing_teammate.can_manage_maap? || viewing_teammate.assigned_employee?
          # Include titles from root company and all its descendants
          # This allows viewing department titles when signed in to company
          org_ids = root_company.self_and_descendants.map(&:id)
          scope.where(organization_id: org_ids)
        else
          scope.none
        end
      end
    end
  end

  private

  def user_has_maap_permission?
    return false unless viewing_teammate
    organization = actual_organization
    return false unless organization
    
    viewing_teammate.can_manage_maap?
  end

  def user_has_maap_permission_for_record?
    return false unless viewing_teammate
    return false unless record&.organization
    viewing_teammate_org = viewing_teammate.organization
    return false unless viewing_teammate_org
    
    # Check if record's organization is in viewing_teammate's organization hierarchy
    orgs = viewing_teammate_org.self_and_descendants
    return false unless orgs.include?(record.organization)
    
    viewing_teammate.can_manage_maap?
  end

  def user_is_active_company_teammate_in_same_company?
    return false unless viewing_teammate
    return false unless record&.organization
    
    # Check if viewing teammate is actively employed (assigned employee)
    return false unless viewing_teammate.assigned_employee?
    
    # Get root companies for both organizations
    viewing_teammate_root_company = viewing_teammate.organization.root_company
    title_root_company = record.organization.root_company
    
    return false unless viewing_teammate_root_company
    return false unless title_root_company
    
    # Check if they're in the same company
    viewing_teammate_root_company.id == title_root_company.id
  end
end
