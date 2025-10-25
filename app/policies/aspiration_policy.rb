class AspirationPolicy < ApplicationPolicy
  def index?
    # Allow all authenticated users to view aspirations index
    true
  end

  def show?
    # Allow all authenticated users to view individual aspirations
    true
  end

  def create?
    admin_bypass? || user_has_maap_permission?
  end

  def update?
    admin_bypass? || user_has_maap_permission_for_record?
  end

  def destroy?
    admin_bypass? || user_has_maap_permission_for_record?
  end

  class Scope < Scope
    def resolve
      if actual_user.og_admin?
        scope.all
      elsif user.respond_to?(:pundit_organization) && user.pundit_organization
        organization = user.pundit_organization
        # Allow all teammates to see aspirations for their organization
        scope.where(organization: organization)
      else
        scope.none
      end
    end
  end

  private

  def user_has_maap_permission?
    return false unless user.respond_to?(:pundit_organization) && user.pundit_organization
    
    organization = user.pundit_organization
    actual_user.teammates.exists?(
      organization: organization,
      can_manage_maap: true
    )
  end

  def user_has_maap_permission_for_record?
    return false unless record&.organization
    
    actual_user.teammates.exists?(
      organization: record.organization,
      can_manage_maap: true
    )
  end
end
