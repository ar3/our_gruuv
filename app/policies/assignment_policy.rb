class AssignmentPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    
    # Users can view assignments in their organization hierarchy
    return false unless viewing_teammate
    user_org = viewing_teammate.organization
    record_org = record.company
    
    # Check if record's organization is in user's organization hierarchy
    return false unless user_org.self_and_descendants.include?(record_org)
    
    true
  end

  def create?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with MAAP permissions can create assignments
    viewing_teammate.person.admin? || user_has_maap_permission?
  end

  def update?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with MAAP permissions can update assignments
    viewing_teammate.person.admin? || user_has_maap_permission_for_record?
  end

  def destroy?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with MAAP permissions can destroy assignments
    viewing_teammate.person.admin? || user_has_maap_permission_for_record?
  end

  def manage_consumer_assignments?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with MAAP permissions can manage consumer assignments
    viewing_teammate.person.admin? || user_has_maap_permission_for_record?
  end

  private

  def user_has_maap_permission?
    return false unless viewing_teammate
    
    # For new records, get organization from record.company or actual_organization
    # For existing records, use record.company
    organization = record.company || actual_organization
    return false unless organization
    
    # Check if organization is in user's hierarchy
    user_org = viewing_teammate.organization
    return false unless user_org.self_and_descendants.include?(organization)
    
    viewing_teammate.can_manage_maap?
  end

  def user_has_maap_permission_for_record?
    return false unless viewing_teammate
    return false unless record&.company
    viewing_teammate_org = viewing_teammate.organization
    return false unless viewing_teammate_org
    
    # Check if record's organization is in viewing_teammate's organization hierarchy
    orgs = viewing_teammate_org.self_and_descendants
    return false unless orgs.include?(record.company)
    
    viewing_teammate.can_manage_maap?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      return scope.all if person.admin?
      
      # Only show assignments in user's organization
      return scope.none unless actual_organization
      
      company = actual_organization.root_company || actual_organization
      scope.where(company: company.self_and_descendants)
    end
  end
end
