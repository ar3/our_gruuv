class PositionPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    
    # Users can view positions in their organization
    return false unless viewing_teammate
    viewing_teammate_org = viewing_teammate.organization
    return false unless viewing_teammate_org
    return false unless record.position_type.organization == viewing_teammate_org ||
                        viewing_teammate_org.self_and_descendants.include?(record.position_type.organization)
    
    true
  end

  def create?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with can_manage_maap permission on company teammate record can create positions
    viewing_teammate.person.admin? || can_manage_maap_for_position_company?
  end

  def update?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with can_manage_maap permission on company teammate record can update positions
    viewing_teammate.person.admin? || can_manage_maap_for_position_company?
  end

  def destroy?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with can_manage_maap permission on company teammate record can destroy positions
    viewing_teammate.person.admin? || can_manage_maap_for_position_company?
  end

  def manage_assignments?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with MAAP permissions can manage assignments
    viewing_teammate.person.admin? || can_manage_assignments?
  end

  private

  def can_manage_maap_for_position_company?
    return false unless viewing_teammate
    return false unless record
    
    # Ensure position_type is loaded
    position_type = record.position_type
    return false unless position_type
    
    # Ensure organization is loaded
    position_org = position_type.organization
    return false unless position_org
    
    # Get the company the position is associated with (root company)
    company = position_org.company? ? position_org : position_org.root_company
    return false unless company
    
    # Find the company teammate record for the viewing person and this company
    company_teammate = CompanyTeammate.find_by(person: viewing_teammate.person, organization: company)
    return false unless company_teammate
    
    # Check if the company teammate has can_manage_maap permission
    company_teammate.can_manage_maap?
  end

  def can_manage_assignments?
    return false unless viewing_teammate
    return false unless actual_organization
    return false unless record.position_type.organization == actual_organization ||
                        actual_organization.self_and_descendants.include?(record.position_type.organization)
    
    # Check if user can manage MAAP in the organization
    Teammate.can_manage_maap_in_hierarchy?(viewing_teammate.person, actual_organization)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      return scope.all if person.admin?
      
      # Only show positions in user's organization
      return scope.none unless actual_organization
      
      orgs = actual_organization.self_and_descendants
      scope.joins(:position_type)
           .where(position_types: { organization: orgs })
    end
  end
end
