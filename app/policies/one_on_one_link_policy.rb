class OneOnOneLinkPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return false if viewing_teammate.terminated?
    return false unless record.teammate&.person
    
    # Can view if viewing own link or if manager
    return true if viewing_teammate.person == record.teammate.person
    return true if viewing_teammate.can_manage_employment?
    record_teammate = record.teammate.is_a?(CompanyTeammate) ? record.teammate : CompanyTeammate.find_by(organization: viewing_teammate.organization, person: record.teammate.person)
    return true if record_teammate && viewing_teammate.in_managerial_hierarchy_of?(record_teammate)
    
    false
  end

  def update?
    show?
  end

  def create?
    # Same as update - can create if they can view
    update?
  end
end

