class PositionPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    
    # Users can view positions in their organization
    return false unless actual_organization
    return false unless record.position_type.organization == actual_organization ||
                        actual_organization.self_and_descendants.include?(record.position_type.organization)
    
    true
  end

  def create?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or managers can create positions
    viewing_teammate.person.admin? || can_manage_positions?
  end

  def update?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or managers can update positions
    viewing_teammate.person.admin? || can_manage_positions?
  end

  def destroy?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins can destroy positions
    viewing_teammate.person.admin?
  end

  private

  def can_manage_positions?
    return false unless viewing_teammate
    return false unless actual_organization
    return false unless record.position_type.organization == actual_organization ||
                        actual_organization.self_and_descendants.include?(record.position_type.organization)
    
    # Check if user can manage employment in the organization
    Teammate.can_manage_employment_in_hierarchy?(viewing_teammate.person, actual_organization)
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
