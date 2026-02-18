class AbilityPolicy < ApplicationPolicy
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

  def archive?
    update?
  end

  def restore?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person&.og_admin?
        scope.all
      else
        return scope.none unless actual_organization
        return scope.none unless viewing_teammate.can_manage_maap?
        scope.where(company_id: actual_organization.id)
      end
    end
  end

  private

  def user_has_maap_permission?
    return false unless viewing_teammate
    organization = actual_organization
    return false unless organization
    viewing_teammate.organization_id == organization.id && viewing_teammate.can_manage_maap?
  end

  def user_has_maap_permission_for_record?
    return false unless viewing_teammate
    return false unless record&.company_id
    viewing_teammate.organization_id == record.company_id && viewing_teammate.can_manage_maap?
  end
end
