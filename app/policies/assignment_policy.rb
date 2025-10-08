class AssignmentPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    
    # Users can view assignments in their current organization
    return false unless actual_user.current_organization
    return false unless record.company == actual_user.current_organization
    
    true
  end

  def create?
    return true if admin_bypass?
    
    # Only admins or managers can create assignments
    actual_user.admin? || can_manage_assignments?
  end

  def update?
    return true if admin_bypass?
    
    # Only admins or managers can update assignments
    actual_user.admin? || can_manage_assignments?
  end

  def destroy?
    return true if admin_bypass?
    
    # Only admins can destroy assignments
    actual_user.admin?
  end

  private

  def can_manage_assignments?
    return false unless actual_user.current_organization
    return false unless record.company == actual_user.current_organization
    
    # Check if user can manage employment in the organization
    Teammate.can_manage_employment_in_hierarchy?(actual_user, actual_user.current_organization)
  end

  class Scope < Scope
    def resolve
      return scope.all if actual_user.admin?
      
      # Only show assignments in user's current organization
      return scope.none unless actual_user.current_organization
      
      scope.where(company: actual_user.current_organization)
    end
  end
end
