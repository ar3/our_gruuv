class PersonPolicy < ApplicationPolicy
  def show?
    # Users can view their own profile, admins can view any, or if they have employment management permissions
    return true if admin_bypass? || user == record
    
    # Check if user has employment management permissions in any organization
    user_employment_orgs = user.employment_tenures.includes(:company).map(&:company)
    user_has_employment_management = user_employment_orgs.any? { |org| user.can_manage_employment?(org) }
    
    user_has_employment_management
  end

  def public?
    # Public profiles are accessible to anyone (no authentication required)
    true
  end

  def teammate?
    # Teammates can view each other's profiles within the same organization
    return true if admin_bypass?
    return false unless user && record
    
    # Requestor must have organization context
    return false unless record.respond_to?(:context) && record.context[:organization]
    user_org = record.context[:organization]
    
    Rails.logger.debug "Teammate check: User #{user.id} (#{user.email}) org: #{user_org.id} (#{user_org.name})"
    
    # Requestor must be active in their current organization
    return false unless user.active_employment_tenure_in?(user_org)
    
    # Subject must have employment within the requestor's organization
    subject_has_employment = record.employment_tenures.where(company: user_org).exists?
    
    Rails.logger.debug "Subject employment in org: #{subject_has_employment}"
    
    subject_has_employment
  end

  def manager?
    # Managers can view detailed profiles of people they manage
    return true if admin_bypass?
    return false unless user && record
    
    # User can access if they have employment management permissions for any organization
    # Check all organizations where user has employment management permissions
    user_employment_orgs = user.employment_tenures.includes(:company).map(&:company)
    user_has_employment_management = user_employment_orgs.any? { |org| user.can_manage_employment?(org) }
    
    Rails.logger.debug "Manager check: User #{user.id} has employment management: #{user_has_employment_management}"
    
    # User can access if they have employment management permissions anywhere
    return true if user_has_employment_management
    
    # User can access if they are in the managerial hierarchy
    return true if user.in_managerial_hierarchy_of?(record)
    
    # User can always access their own manager view
    return true if user == record
    
    false
  end

  def employment_summary?
    # Users can view their own employment summary, admins can view any
    admin_bypass? || user == record
  end

  def view_employment_history?
    # Users can view employment history if they are:
    # 1. The person themselves
    # 2. In their managerial hierarchy 
    # 3. Have employment management permissions for any organization
    return true if admin_bypass? || user == record || user.in_managerial_hierarchy_of?(record)
    
    # Check if user has employment management permissions in any organization
    user_employment_orgs = user.employment_tenures.includes(:company).map(&:company)
    user_has_employment_management = user_employment_orgs.any? { |org| user.can_manage_employment?(org) }
    
    user_has_employment_management
  end

  def manage_assignments?
    # Users can manage assignments if they are:
    # 1. The person themselves
    # 2. In their managerial hierarchy 
    # 3. Have BOTH employment management AND MAAP management permissions for any organization
    return true if admin_bypass? || user == record || user.in_managerial_hierarchy_of?(record)
    
    # Check for both permissions across all user's organizations
    user_employment_orgs = user.employment_tenures.includes(:company).map(&:company)
    user_has_both_permissions = user_employment_orgs.any? do |org| 
      user.can_manage_employment?(org) && user.can_manage_maap?(org)
    end
    
    user_has_both_permissions
  end

  def change_employment?
    # Users can change employment if they are:
    # 1. The person themselves
    # 2. In their managerial hierarchy 
    # 3. Have employment management permissions for any organization
    return true if admin_bypass? || user == record || user.in_managerial_hierarchy_of?(record)
    
    # Check if user has employment management permissions in any organization
    user_employment_orgs = user.employment_tenures.includes(:company).map(&:company)
    user_employment_management = user_employment_orgs.any? { |org| user.can_manage_employment?(org) }
    
    user_employment_management
  end

  def change?
    # Users can change their own employment, admins can change any
    admin_bypass? || user == record
  end

  def choose_assignments?
    # Users can choose assignments for themselves, admins can choose for anyone
    admin_bypass? || user == record
  end

  def update_assignments?
    # Users can update assignments for themselves, admins can update for anyone
    admin_bypass? || user == record
  end

  def view_other_companies?
    # Users can view their own other companies, og_admin can view any
    admin_bypass? || user == record
  end



  def edit?
    # Users can only edit their own profile
    admin_bypass? || user == record
  end

  def update?
    # Users can update their own profile and assignments, admins can update any
    admin_bypass? || user == record
  end

  def create?
    # Anyone can create a person (during join process)
    true
  end

  def index?
    # Only admins can see the people index
    admin_bypass?
  end

  def destroy?
    # Users cannot delete their own profile (for now)
    admin_bypass? || false
  end

  def connect_google_identity?
    # Users can connect Google accounts to their own profile
    admin_bypass? || user == record
  end

  def disconnect_identity?
    # Users can disconnect identities from their own profile
    admin_bypass? || user == record
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

  class Scope < Scope
    def resolve
      # Users can only see themselves, admins can see all people
      if user&.admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end


end
