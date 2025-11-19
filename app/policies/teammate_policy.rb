class TeammatePolicy < ApplicationPolicy
  def new?
    return true if admin_bypass?
    return false unless viewing_teammate
    person = viewing_teammate.person
    # Users can only create permissions for themselves
    # For new permissions, allow if person is current user (regardless of existing permissions)
    record.person == person
  end

  def create?
    return true if admin_bypass?
    return false unless viewing_teammate
    person = viewing_teammate.person
    # Users can only create permissions for themselves
    # For new permissions, allow if person is current user
    record.person == person
  end

  def edit?
    return true if admin_bypass?
    return false unless viewing_teammate
    person = viewing_teammate.person
    return false unless person == record.person
    return false unless record.organization
    # Users can only edit their own permissions within organizations they have access to
    policy(record.organization).manage_employment?
  end

  def update?
    return true if admin_bypass?
    return false unless viewing_teammate
    person = viewing_teammate.person
    return false unless person == record.person
    return false unless record.organization
    # Users can only update their own permissions within organizations they have access to
    policy(record.organization).manage_employment?
  end

  def destroy?
    return true if admin_bypass?
    return false unless viewing_teammate
    person = viewing_teammate.person
    return false unless person == record.person
    return false unless record.organization
    # Users can only destroy their own permissions within organizations they have access to
    policy(record.organization).manage_employment?
  end
end
