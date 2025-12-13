class CompanyTeammatePolicy < ApplicationPolicy
  def show?
    # Users can view their own teammate record, admins can view any, or if they have employment management or MAAP permissions
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return false if viewing_teammate.terminated?
    return true if viewing_teammate == record
    return true if viewing_teammate.can_manage_employment?
    return true if viewing_teammate.in_managerial_hierarchy_of?(record)
    false
  end

  def update?
    show?
  end

  def complete_picture?
    # Can view complete picture if they can view teammate
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return false if viewing_teammate.terminated?
    return true if viewing_teammate == record
    return true if viewing_teammate.can_manage_employment?
    return true if viewing_teammate.in_managerial_hierarchy_of?(record)
    false
  end

  def internal?
    # Internal teammate view - same as teammate? from PersonPolicy
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return true if viewing_teammate == record
    return false unless viewing_teammate.employed?
    # Record must have employment in the organization
    record.employment_tenures.active.where(company: viewing_teammate.organization).exists?
  end

  def view_check_ins?
    audit?
  end

  def manage_assignments?
    audit?
  end

  def update_permission?
    # Can update permissions if manager
    manager?
  end

  def manager?
    audit?
  end

  def audit?
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return false if viewing_teammate.terminated?
    # Allow users to view their own teammate record
    return true if viewing_teammate == record
    # Trust teammate status exclusively - if teammate is active (employed), allow access
    return false unless viewing_teammate.employed?
    return true if viewing_teammate.can_manage_employment?
    return true if viewing_teammate.in_managerial_hierarchy_of?(record)
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can only see their own teammate record
      return scope.none unless viewing_teammate
      scope.where(id: viewing_teammate.id)
    end
  end
end

