class PersonPolicy < ApplicationPolicy
  def show?
    # Users can view their own profile, admins can view any, or if they have employment management or MAAP permissions
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return false if viewing_teammate.terminated?
    return true if viewing_teammate.person == record
    return true if viewing_teammate.can_manage_employment?
    return true if viewing_teammate.person.in_managerial_hierarchy_of?(record, viewing_teammate.organization)
    false
  end
  
  def public?
    # Public profiles are accessible to anyone (no authentication required)
    true
  end
  
  def teammate?
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return true if viewing_teammate.person == record
    return true if viewing_teammate.employed? && 
    record.teammates.where(organization: viewing_teammate.organization).first.present?
    false
  end
  
  def audit?
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return false if viewing_teammate.terminated?
    return false if !viewing_teammate.has_active_employment_tenure?
    return true if viewing_teammate.person == record
    return true if viewing_teammate.can_manage_employment?
    return true if viewing_teammate.person.in_managerial_hierarchy_of?(record, viewing_teammate.organization)
    false
  end

  def can_view_manage_mode?
    audit?
  end

  def manager?
    audit?
  end

  def employment_summary?
    audit?
  end

  def view_employment_history?
    audit?
  end


  def manage_assignments?
    audit?
  end

  def change_employment?
    audit?
  end

  def change?
    show?
  end

  def choose_assignments?
    audit?
  end

  def update_assignments?
    audit?
  end

  def view_other_companies?
    # Users can view their own other companies, og_admin can view any
    admin_bypass? || viewing_teammate.person == record
  end

  def view_check_ins?
    audit?
  end

  def edit?
    show?
  end

  def update?
    show?
  end

  def create?
    # Anyone can create a person (during join process)
    true
  end


  def destroy?
    # Users cannot delete their own profile (for now)
    admin_bypass? || false
  end

  def connect_google_identity?
    # Users can connect Google accounts to their own profile
    admin_bypass? || viewing_teammate.person == record
  end

  def disconnect_identity?
    # Users can disconnect identities from their own profile
    admin_bypass? || viewing_teammate.person == record
  end

  def can_impersonate?
    # Only og_admin users can impersonate others, and they cannot impersonate other og_admin users
    admin_bypass?
  end

  def can_impersonate_anyone?
    # Check if user has permission to impersonate anyone (for controller-level checks)
    admin_bypass?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can only see their own profile
      return scope.none unless viewing_teammate
      scope.where(id: viewing_teammate.person.id)
    end
  end

end
