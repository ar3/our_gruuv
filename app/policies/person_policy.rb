class PersonPolicy < ApplicationPolicy
  def show?
    # Users can view their own profile and assignment management, admins can view any
    user == record || user.admin?
  end

  def public?
    # Public profiles are accessible to anyone (no authentication required)
    true
  end

  def teammate?
    # Teammates can view each other's profiles within the same organization
    return false unless user && record
    
    # Check if both users are active employees in the same organization
    user_org = user.current_organization
    record_org = record.current_organization
    
    return false unless user_org && record_org
    return false unless user_org == record_org
    
    # Both must be active employees in the same organization
    user.active_employment_tenure_in?(user_org) && record.active_employment_tenure_in?(record_org)
  end

  def manager?
    # Managers can view detailed profiles of people they manage
    return false unless user && record
    
    # User can access if they have employment management permissions
    return true if user.can_manage_employment?(record.current_organization)
    
    # User can access if they are in the managerial hierarchy
    return true if user.in_managerial_hierarchy_of?(record)
    
    # User can always access their own manager view
    return true if user == record
    
    false
  end

  def employment_summary?
    # Users can view their own employment summary, admins can view any
    user == record || user.admin?
  end

  def change?
    # Users can change their own employment, admins can change any
    user == record || user.admin?
  end

  def choose_assignments?
    # Users can choose assignments for themselves, admins can choose for anyone
    user == record || user.admin?
  end

  def update_assignments?
    # Users can update assignments for themselves, admins can update for anyone
    user == record || user.admin?
  end



  def edit?
    # Users can only edit their own profile
    user == record
  end

  def update?
    # Users can update their own profile and assignments, admins can update any
    user == record || user.admin?
  end

  def create?
    # Anyone can create a person (during join process)
    true
  end

  def index?
    # Only admins can see the people index
    user.admin?
  end

  def destroy?
    # Users cannot delete their own profile (for now)
    false
  end

  def connect_google_identity?
    # Users can connect Google accounts to their own profile
    user == record
  end

  def disconnect_identity?
    # Users can disconnect identities from their own profile
    user == record
  end

  class Scope < Scope
    def resolve
      # Users can only see themselves, admins can see all people
      if user.admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end
