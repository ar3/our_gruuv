class PersonOrganizationAccessPolicy < ApplicationPolicy
  def new?
    return false unless user
    # Users can only create permissions for themselves
    # For new permissions, allow if person is current user (regardless of existing permissions)
    record.person == user
  end

  def create?
    return false unless user
    # Users can only create permissions for themselves
    # For new permissions, allow if person is current user (regardless of existing permissions)
    record.person == user
  end

  def edit?
    return false unless user
    # Users can only edit their own permissions within organizations they have access to
    user == record.person && user.can_manage_employment?(record.organization)
  end

  def update?
    return false unless user
    # Users can only update their own permissions within organizations they have access to
    user == record.person && user.can_manage_employment?(record.organization)
  end

  def destroy?
    return false unless user
    # Users can only destroy their own permissions within organizations they have access to
    user == record.person && user.can_manage_employment?(record.organization)
  end
end
