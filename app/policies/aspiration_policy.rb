class AspirationPolicy < ApplicationPolicy
  def index?
    admin_bypass? || user_has_maap_permission?
  end

  def show?
    admin_bypass? || user_has_maap_permission_for_record?
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
        if actual_user.person_organization_accesses.exists?(organization: organization, can_manage_maap: true)
          scope.where(organization: organization)
        else
          scope.none
        end
      else
        scope.none
      end
    end
  end

  private

  def user_has_maap_permission?
    return false unless user.respond_to?(:pundit_organization) && user.pundit_organization
    
    organization = user.pundit_organization
    actual_user.person_organization_accesses.exists?(
      organization: organization,
      can_manage_maap: true
    )
  end

  def user_has_maap_permission_for_record?
    return false unless record&.organization
    
    actual_user.person_organization_accesses.exists?(
      organization: record.organization,
      can_manage_maap: true
    )
  end
end
