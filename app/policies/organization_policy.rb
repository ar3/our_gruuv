class OrganizationPolicy < ApplicationPolicy
  def show?
    admin_bypass? || true # Anyone can view organization details
  end

  def manage_employment?
    admin_bypass? || (user && user.can_manage_employment?(record))
  end
  
  def create_employment?
    admin_bypass? || (user && user.can_create_employment?(record))
  end

  def manage_maap?
    admin_bypass? || (user && user.can_manage_maap?(record))
  end

  def create?
    admin_bypass? || (user && user.can_manage_employment?(record))
  end

  def update?
    admin_bypass? || (user && user.can_manage_employment?(record))
  end

  def destroy?
    admin_bypass? || (user && user.can_manage_employment?(record))
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.all # Organizations are generally viewable by all authenticated users
      end
    end
  end
end
