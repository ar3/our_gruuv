# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :pundit_user, :record

  def initialize(pundit_user, record)
    @pundit_user = pundit_user
    @record = record
    validate_teammate!
  end

  # Admin bypass - og_admin users get all permissions
  def admin_bypass?
    viewing_teammate.person&.og_admin? || false
  end

  # Helper method to get the teammate from pundit_user
  # Returns a CompanyTeammate (or nil if not logged in)
  def viewing_teammate
    @viewing_teammate ||= pundit_user.respond_to?(:user) ? pundit_user.user : pundit_user
    return nil unless @viewing_teammate.is_a?(CompanyTeammate)
    @viewing_teammate
  end

  # Helper method to get an Organization from the teammate and record context
  # For organization-scoped records, derive from record.organization when available
  # Otherwise, use teammate.organization
  def actual_organization
    # For OrganizationPolicy, organization comes from the record itself
    return record if record.is_a?(Organization)
    
    # For organization-scoped records, try to get organization from record first
    if record.respond_to?(:organization) && record.organization
      return record.organization
    end
    
    # Fall back to teammate's organization
    viewing_teammate&.organization
  end

  # Public policy methods - Pundit requires these to be public
  def new?
    admin_bypass? || create?
  end

  def edit?
    admin_bypass? || update?
  end

  private

  def validate_teammate!
    return if viewing_teammate.nil? # Allow nil for unauthenticated checks
    
    unless viewing_teammate.is_a?(CompanyTeammate)
      raise ArgumentError, "Policies must receive a CompanyTeammate, got #{teammate_obj.class.name}. Use teammate.person if you need the person."
    end
  end

  def index?
    admin_bypass? || false
  end

  def show?
    admin_bypass? || false
  end

  def create?
    admin_bypass? || false
  end

  def update?
    admin_bypass? || false
  end

  def destroy?
    admin_bypass? || false
  end

  class Scope
    def initialize(pundit_user, scope)
      @pundit_user = pundit_user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :pundit_user, :scope

    # Helper method to get the teammate from pundit_user
    # Returns a CompanyTeammate (or nil if not logged in)
    def viewing_teammate
      @viewing_teammate ||= pundit_user.respond_to?(:user) ? pundit_user.user : pundit_user
      return nil unless @viewing_teammate.is_a?(CompanyTeammate)
      @viewing_teammate
    end

    # Helper method to get an Organization from the teammate and scope context
    def actual_organization
      # For organization-scoped scopes, try to infer from scope
      # Otherwise, use teammate's organization
      viewing_teammate&.organization
    end

    # Helper method for admin bypass in scope classes
    # When impersonating, use the impersonated user's permissions (not the admin's)
    # This ensures scopes show what the impersonated user can see
    def admin_bypass?
      return false unless viewing_teammate
      viewing_teammate.person&.og_admin?
    end
  end
end
