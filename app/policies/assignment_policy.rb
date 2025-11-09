class AssignmentPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    
    # Users can view assignments in their organization
    return false unless actual_organization
    return false unless record.company == actual_organization.root_company || 
                        record.company.self_and_descendants.include?(actual_organization)
    
    true
  end

  def create?
    return true if admin_bypass?
    return false unless teammate
    
    # Only admins or managers can create assignments
    teammate.person.admin? || can_manage_assignments?
  end

  def update?
    return true if admin_bypass?
    return false unless teammate
    
    # Only admins or managers can update assignments
    teammate.person.admin? || can_manage_assignments?
  end

  def destroy?
    return true if admin_bypass?
    return false unless teammate
    
    # Only admins can destroy assignments
    teammate.person.admin?
  end

  private

  def can_manage_assignments?
    return false unless teammate
    return false unless actual_organization
    return false unless record.company == actual_organization.root_company || 
                        record.company.self_and_descendants.include?(actual_organization)
    
    # Check if user can manage employment in the organization
    Teammate.can_manage_employment_in_hierarchy?(teammate.person, actual_organization)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless teammate
      person = teammate.person
      return scope.all if person.admin?
      
      # Only show assignments in user's organization
      return scope.none unless actual_organization
      
      company = actual_organization.root_company || actual_organization
      scope.where(company: company.self_and_descendants)
    end
  end
end
