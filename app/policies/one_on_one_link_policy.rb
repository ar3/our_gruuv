class OneOnOneLinkPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return false if viewing_teammate.terminated?
    return false unless record.teammate&.person
    
    # Can view if viewing own link or if manager
    return true if viewing_teammate.person == record.teammate.person
    return true if viewing_teammate.can_manage_employment?
    return true if viewing_teammate.person.in_managerial_hierarchy_of?(record.teammate.person, viewing_teammate.organization)
    
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

