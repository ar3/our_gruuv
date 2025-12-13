class PersonPolicy < ApplicationPolicy
  # Person-level (non-organization-scoped) actions only
  # Organization-scoped actions have moved to CompanyTeammatePolicy
  
  def public?
    # Public profiles are accessible to anyone (no authentication required)
    true
  end

  def show?
    # Users can view their own profile, admins can view any
    return true if admin_bypass?
    return false unless viewing_teammate
    viewing_teammate.person == record
  end

  def edit?
    # Users can edit their own profile, admins can edit any, or managers with employment management permissions
    return true if admin_bypass?
    return false unless viewing_teammate
    return true if viewing_teammate.person == record
    
    # Check if user has employment management permissions
    return true if viewing_teammate.can_manage_employment?
    
    # Check if user is in managerial hierarchy of the person
    # Query directly from database to avoid association caching issues
    record_teammate = CompanyTeammate.find_by(organization: viewing_teammate.organization, person: record)
    return false unless record_teammate
    return true if viewing_teammate.in_managerial_hierarchy_of?(record_teammate)
    
    false
  end

  def update?
    edit?
  end

  def create?
    # Anyone can create a person
    true
  end

  def teammate?
    # Check if viewing teammate can view this person as a teammate in the same organization
    # When impersonating, use impersonated user's permissions (not admin's)
    return true if admin_bypass? && (!pundit_user.respond_to?(:impersonating_teammate) || !pundit_user.impersonating_teammate)
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?
    
    # When impersonating, use impersonated user's permissions
    # The viewing_teammate is already the impersonated user (from pundit_user.user)
    actual_teammate = viewing_teammate
    return false unless actual_teammate.employed?
    
    # Check if record has employment in the same organization
    # Query directly from database to avoid association caching issues
    record_teammate = CompanyTeammate.find_by(organization: actual_teammate.organization, person: record)
    return false unless record_teammate
    record_teammate.employment_tenures.active.where(company: actual_teammate.organization).exists?
  end

  def view_other_companies?
    # Users can view their own other companies, admins can view any
    return true if admin_bypass?
    return false unless viewing_teammate
    viewing_teammate.person == record
  end

  def view_check_ins?
    # Users can view their own check-ins, or if they have employment management permissions or are in managerial hierarchy
    # When impersonating, use impersonated user's permissions (not admin's)
    is_impersonating = pundit_user.respond_to?(:impersonating_teammate) && pundit_user.impersonating_teammate
    return true if admin_bypass? && !is_impersonating
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?
    
    # When impersonating, use impersonated user's permissions (viewing_teammate is already the impersonated user)
    actual_teammate = viewing_teammate
    
    # Allow users to view their own check-ins
    return true if actual_teammate.person == record
    
    # Check if user has employment management permissions
    return true if actual_teammate.can_manage_employment?
    
    # Check if user is in managerial hierarchy of the person
    # Query directly from database to avoid association caching issues
    record_teammate = CompanyTeammate.find_by(organization: actual_teammate.organization, person: record)
    return false unless record_teammate
    actual_teammate.in_managerial_hierarchy_of?(record_teammate)
  end

  def manage_assignments?
    # Same as audit? - delegate to audit method
    audit?
  end


  def audit?
    # Users can view their own audit, or if they have MAAP management permissions and are in managerial hierarchy
    return true if admin_bypass?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?
    
    # Allow users to view their own audit
    return true if viewing_teammate.person == record
    
    # Check if user has MAAP management permissions
    return false unless viewing_teammate.can_manage_maap?
    
    # Check if user is in managerial hierarchy of the person
    # Query directly from database to avoid association caching issues
    record_teammate = CompanyTeammate.find_by(organization: viewing_teammate.organization, person: record)
    return false unless record_teammate
    viewing_teammate.in_managerial_hierarchy_of?(record_teammate)
  end

  def change_employment?
    # Users with employment management permissions can change employment, or managers in hierarchy
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Check if user has employment management permissions
    return true if viewing_teammate.can_manage_employment?
    
    # Check if user is in managerial hierarchy of the person
    # Query directly from database to avoid association caching issues
    record_teammate = CompanyTeammate.find_by(organization: viewing_teammate.organization, person: record)
    return false unless record_teammate
    viewing_teammate.in_managerial_hierarchy_of?(record_teammate)
  end

  def destroy?
    # Users cannot destroy profiles (even their own)
    false
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
    # Only og_admin users can impersonate others
    # TODO: In the future, prevent admins from impersonating other og_admin users by checking:
    #   return false if record.og_admin? && viewing_teammate.person.og_admin?
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

