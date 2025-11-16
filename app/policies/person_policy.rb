class PersonPolicy < ApplicationPolicy
  def show?
    # Users can view their own profile, admins can view any, or if they have employment management or MAAP permissions
    return true if admin_bypass? || teammate.person == record
    
    person = teammate.person
    # Check if user has employment management permissions in any organization
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    user_has_employment_management = user_employment_orgs.any? { |org| person.can_manage_employment?(org) }
    user_has_maap_management = user_employment_orgs.any? { |org| person.can_manage_maap?(org) }
    
    # Allow access if user has either employment management OR MAAP management permissions
    user_has_employment_management || user_has_maap_management
  end

  def public?
    # Public profiles are accessible to anyone (no authentication required)
    true
  end

  def teammate?
    # Teammates can view each other's profiles within the same organization
    return true if admin_bypass?
    return false unless teammate && record
    
    # Get organization from teammate
    user_org = actual_organization
    return false unless user_org
    
    person = teammate.person
    Rails.logger.debug "Teammate check: User #{person.id} (#{person.email}) org: #{user_org.id} (#{user_org.name})"
    
    # Requestor must be active in their current organization
    return false unless person.active_employment_tenure_in?(user_org)
    
    # Subject must have employment within the requestor's organization
    subject_has_employment = record.employment_tenures.where(company: user_org).exists?
    
    Rails.logger.debug "Subject employment in org: #{subject_has_employment}"
    
    subject_has_employment
  end

  def can_view_manage_mode?
    # Users can view management mode pages if they are:
    # 1. The person themselves (employees can view their own management mode)
    # 2. In their managerial hierarchy 
    # 3. Have employment management permissions for any organization
    person = teammate.person
    return true if admin_bypass? || person == record
    
    # Check if user is in managerial hierarchy for any organization
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    return true if user_employment_orgs.any? { |org| person.in_managerial_hierarchy_of?(record, org) }
    
    # Check if user has employment management permissions in any organization
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    user_has_employment_management = user_employment_orgs.any? { |org| person.can_manage_employment?(org) }
    
    Rails.logger.debug "Manage mode check: User #{person.id} has employment management: #{user_has_employment_management}"
    
    user_has_employment_management
  end

  def manager?
    # Managers can view detailed profiles of people they manage
    return true if admin_bypass?
    return false unless teammate && record
    
    person = teammate.person
    # User can access if they have employment management permissions for any organization
    # Check all organizations where user has employment management permissions
    user_employment_orgs = person.teammates.includes(:organization).map(&:organization)
    user_has_employment_management = user_employment_orgs.any? { |org| person.can_manage_employment?(org) }
    
    Rails.logger.debug "Manager check: User #{person.id} has employment management: #{user_has_employment_management}"
    
    # User can access if they have employment management permissions anywhere
    return true if user_has_employment_management
    
    # User can access if they are in the managerial hierarchy for any organization
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    return true if user_employment_orgs.any? { |org| person.in_managerial_hierarchy_of?(record, org) }
    
    # User can always access their own manager view
    return true if person == record
    
    false
  end

  def employment_summary?
    # Users can view their own employment summary, admins can view any
    admin_bypass? || teammate.person == record
  end

  def view_employment_history?
    # Users can view employment history if they are:
    # 1. The person themselves
    # 2. In their managerial hierarchy 
    # 3. Have employment management permissions for any organization
    person = teammate.person
    return true if admin_bypass? || person == record
    
    # Check if user is in managerial hierarchy for any organization
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    return true if user_employment_orgs.any? { |org| person.in_managerial_hierarchy_of?(record, org) }
    
    # Check if user has employment management permissions in any organization
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    user_has_employment_management = user_employment_orgs.any? { |org| person.can_manage_employment?(org) }
    
    user_has_employment_management
  end

  def audit?
    # Users can view MAAP audit if they are:
    # 1. The person themselves
    # 2. In their managerial hierarchy 
    # 3. Have MAAP management permissions for the specific organization
    person = teammate.person
    return true if admin_bypass? || person == record
    
    # Get organization from teammate
    organization = actual_organization
    return false unless organization
    
    return true if person.in_managerial_hierarchy_of?(record, organization)
    
    # Check if user has MAAP management permissions for the specific organization
    person.can_manage_maap?(organization)
  end

  def manage_assignments?
    # Users can manage assignments if they are:
    # 1. The person themselves
    # 2. In their managerial hierarchy 
    # 3. Have BOTH employment management AND MAAP management permissions for any organization
    person = teammate.person
    return true if admin_bypass? || person == record
    
    # Check if user is in managerial hierarchy for any organization
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    return true if user_employment_orgs.any? { |org| person.in_managerial_hierarchy_of?(record, org) }
    
    # Check for both permissions across all user's organizations
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    user_has_both_permissions = user_employment_orgs.any? do |org| 
      person.can_manage_employment?(org) && person.can_manage_maap?(org)
    end
    
    user_has_both_permissions
  end

  def change_employment?
    # Users can change employment if they are:
    # 1. The person themselves
    # 2. In their managerial hierarchy 
    # 3. Have employment management permissions for any organization
    person = teammate.person
    return true if admin_bypass? || person == record
    
    # Check if user is in managerial hierarchy for any organization
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    return true if user_employment_orgs.any? { |org| person.in_managerial_hierarchy_of?(record, org) }
    
    # Check if user has employment management permissions in any organization
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    user_employment_management = user_employment_orgs.any? { |org| person.can_manage_employment?(org) }
    
    user_employment_management
  end

  def change?
    # Users can change their own employment, admins can change any
    admin_bypass? || teammate.person == record
  end

  def choose_assignments?
    # Users can choose assignments for themselves, admins can choose for anyone
    admin_bypass? || teammate.person == record
  end

  def update_assignments?
    # Users can update assignments for themselves, admins can update for anyone
    admin_bypass? || teammate.person == record
  end

  def view_other_companies?
    # Users can view their own other companies, og_admin can view any
    admin_bypass? || teammate.person == record
  end

  def view_check_ins?
    # Users can view check-ins if they are:
    # 1. The person themselves
    # 2. In their managerial hierarchy 
    # 3. Have employment management permissions for the specific organization
    person = teammate.person
    return true if admin_bypass? || person == record
    
    # Get organization from teammate
    user_org = actual_organization
    return false unless user_org
    
    # Check if user is in managerial hierarchy for the specific organization
    return true if person.in_managerial_hierarchy_of?(record, user_org)
    
    # Check if user has employment management permissions in the SPECIFIC organization
    person.can_manage_employment?(user_org)
  end



  def edit?
    # Users can edit profiles if they are:
    # 1. The person themselves (employees can edit their own profile)
    # 2. In their managerial hierarchy 
    # 3. Have employment management permissions for any organization
    person = teammate.person
    return true if admin_bypass? || person == record
    
    # Check if user is in managerial hierarchy for any organization
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    return true if user_employment_orgs.any? { |org| person.in_managerial_hierarchy_of?(record, org) }
    
    # Check if user has employment management permissions in any organization
    user_has_employment_management = user_employment_orgs.any? { |org| person.can_manage_employment?(org) }
    
    user_has_employment_management
  end

  def update?
    # Users can update profiles if they are:
    # 1. The person themselves (employees can update their own profile)
    # 2. In their managerial hierarchy 
    # 3. Have employment management permissions for any organization
    person = teammate.person
    return true if admin_bypass? || person == record
    
    # Check if user is in managerial hierarchy for any organization
    user_employment_orgs = person.employment_tenures.includes(:company).map(&:company)
    return true if user_employment_orgs.any? { |org| person.in_managerial_hierarchy_of?(record, org) }
    
    # Check if user has employment management permissions in any organization
    user_has_employment_management = user_employment_orgs.any? { |org| person.can_manage_employment?(org) }
    
    user_has_employment_management
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
    admin_bypass? || teammate.person == record
  end

  def disconnect_identity?
    # Users can disconnect identities from their own profile
    admin_bypass? || teammate.person == record
  end

  def can_impersonate?
    # Only og_admin users can impersonate others, and they cannot impersonate other og_admin users
    return false unless admin_bypass?
    return false if record&.og_admin? # Can't impersonate other admins
    true
  end

  def can_impersonate_anyone?
    # Check if user has permission to impersonate anyone (for controller-level checks)
    admin_bypass?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can only see their own profile
      return scope.none unless teammate
      scope.where(id: teammate.person.id)
    end
  end

end
