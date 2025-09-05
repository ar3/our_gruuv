class CompanyPolicy < OrganizationPolicy
  # Inherits all methods from OrganizationPolicy
  # Can override specific methods if needed for company-specific logic
  
  def manage_assignments?
    admin_bypass? || (actual_user && actual_user.can_manage_maap?(record))
  end

  def manage_employment?
    admin_bypass? || (actual_user && actual_user.can_manage_employment?(record))
  end

  def create_employment?
    admin_bypass? || (actual_user && actual_user.can_create_employment?(record))
  end

  class Scope < Scope
    def resolve
      if actual_user&.admin?
        scope.all
      else
        scope.all # Companies are generally viewable by all authenticated users
      end
    end
  end
end
