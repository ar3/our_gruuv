class CompanyPolicy < OrganizationPolicy
  # Inherits all methods from OrganizationPolicy
  # Can override specific methods if needed for company-specific logic
  
  def manage_assignments?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_maap?
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

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person&.admin?
        scope.all
      else
        scope.all # Companies are generally viewable by all authenticated users
      end
    end
  end
end
