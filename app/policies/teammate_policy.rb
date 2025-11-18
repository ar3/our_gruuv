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
    # Users can only edit their own permissions within organizations they have access to
    person == record.person && person.can_manage_employment?(record.organization)
  end

  def update?
    return true if admin_bypass?
    return false unless viewing_teammate
    person = viewing_teammate.person
    # Users can only update their own permissions within organizations they have access to
    person == record.person && person.can_manage_employment?(record.organization)
  end

  def destroy?
    return true if admin_bypass?
    return false unless viewing_teammate
    person = viewing_teammate.person
    # Users can only destroy their own permissions within organizations they have access to
    person == record.person && person.can_manage_employment?(record.organization)
  end
end
