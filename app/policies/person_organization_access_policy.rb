class PersonOrganizationAccessPolicy < ApplicationPolicy
  def new?
    return true if admin_bypass?
    return false unless actual_user
    # Users can only create permissions for themselves
    # For new permissions, allow if person is current user (regardless of existing permissions)
    record.person == actual_user
  end

  def create?
    return true if admin_bypass?
    return false unless actual_user
    # Users can only create permissions for themselves
    # For new permissions, allow if person is current user
    record.person == actual_user
  end

  def edit?
    return true if admin_bypass?
    return false unless actual_user
    # Users can only edit their own permissions within organizations they have access to
    actual_user == record.person && actual_user.can_manage_employment?(record.organization)
  end

  def update?
    return true if admin_bypass?
    return false unless actual_user
    # Users can only update their own permissions within organizations they have access to
    actual_user == record.person && actual_user.can_manage_employment?(record.organization)
  end

  def destroy?
    return true if admin_bypass?
    return false unless actual_user
    # Users can only destroy their own permissions within organizations they have access to
    actual_user == record.person && actual_user.can_manage_employment?(record)
  end
end
