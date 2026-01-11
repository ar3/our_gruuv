class AssignmentOutcomePolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    
    # Users can view outcomes for assignments they can view
    return false unless viewing_teammate
    assignment = record.assignment
    return false unless assignment
    
    user_org = viewing_teammate.organization
    record_org = assignment.company
    return false unless user_org && record_org
    
    # Check if record's organization is in user's organization hierarchy
    return false unless user_org.self_and_descendants.include?(record_org)
    
    true
  end

  def edit?
    return true if admin_bypass?
    return false unless viewing_teammate
    return false unless record.assignment
    
    # Only admins or users with MAAP permissions can edit outcomes
    viewing_teammate.person&.og_admin? || user_has_maap_permission?
  end

  def update?
    edit?
  end

  # Override actual_organization to get organization from assignment
  def actual_organization
    return record.assignment.company if record.respond_to?(:assignment) && record.assignment&.company
    viewing_teammate&.organization
  end

  private

  def user_has_maap_permission?
    return false unless viewing_teammate
    return false unless record&.assignment&.company
    
    viewing_teammate_org = viewing_teammate.organization
    return false unless viewing_teammate_org
    
    # Check if record's organization is in viewing_teammate's organization hierarchy
    orgs = viewing_teammate_org.self_and_descendants
    return false unless orgs.include?(record.assignment.company)
    
    viewing_teammate.can_manage_maap?
  end
end
