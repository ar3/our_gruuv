class OrganizationPolicy < ApplicationPolicy
  def show?
    admin_bypass? || true # Anyone can view organization details
  end

  def manage_employment?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end
  
  def create_employment?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_create_employment?
  end

  def manage_maap?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_maap?
  end

  def create?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def update?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def destroy?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def check_ins_health?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person&.admin?
        scope.all
      else
        scope.all # Organizations are generally viewable by all authenticated users
      end
    end
  end
end
