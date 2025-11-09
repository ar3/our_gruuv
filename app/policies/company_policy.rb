class CompanyPolicy < OrganizationPolicy
  # Inherits all methods from OrganizationPolicy
  # Can override specific methods if needed for company-specific logic
  
  def manage_assignments?
    return false unless teammate
    person = teammate.person
    admin_bypass? || (person && person.can_manage_maap?(record))
  end

  def manage_employment?
    return false unless teammate
    person = teammate.person
    admin_bypass? || (person && person.can_manage_employment?(record))
  end

  def create_employment?
    return false unless teammate
    person = teammate.person
    admin_bypass? || (person && person.can_create_employment?(record))
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless teammate
      person = teammate.person
      if person&.admin?
        scope.all
      else
        scope.all # Companies are generally viewable by all authenticated users
      end
    end
  end
end
