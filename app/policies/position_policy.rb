class PositionPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    
    # Users can view positions in their current organization
    return false unless actual_user.current_organization
    return false unless record.position_type.organization == actual_user.current_organization
    
    true
  end

  def create?
    return true if admin_bypass?
    
    # Only admins or managers can create positions
    actual_user.admin? || can_manage_positions?
  end

  def update?
    return true if admin_bypass?
    
    # Only admins or managers can update positions
    actual_user.admin? || can_manage_positions?
  end

  def destroy?
    return true if admin_bypass?
    
    # Only admins can destroy positions
    actual_user.admin?
  end

  private

  def can_manage_positions?
    return false unless actual_user.current_organization
    return false unless record.position_type.organization == actual_user.current_organization
    
    # Check if user can manage employment in the organization
    Teammate.can_manage_employment_in_hierarchy?(actual_user, actual_user.current_organization)
  end

  class Scope < Scope
    def resolve
      return scope.all if actual_user.admin?
      
      # Only show positions in user's current organization
      return scope.none unless actual_user.current_organization
      
      scope.joins(:position_type)
           .where(position_types: { organization: actual_user.current_organization })
    end
  end
end
