class OrganizationPolicy < ApplicationPolicy
  def show?
    admin_bypass? || true # Anyone can view organization details
  end

  def manage_employment?
    admin_bypass? || (actual_user && actual_user.can_manage_employment?(record))
  end
  
  def create_employment?
    admin_bypass? || (actual_user && actual_user.can_create_employment?(record))
  end

  def manage_maap?
    admin_bypass? || (actual_user && actual_user.can_manage_maap?(record))
  end

  def create?
    admin_bypass? || (actual_user && actual_user.can_manage_employment?(record))
  end

  def update?
    admin_bypass? || (actual_user && actual_user.can_manage_employment?(record))
  end

  def destroy?
    admin_bypass? || (actual_user && actual_user.can_manage_employment?(record))
  end

  def check_ins_health?
    admin_bypass? || (actual_user && actual_user.can_manage_employment?(record))
  end

  class Scope < Scope
    def resolve
      if actual_user&.admin?
        scope.all
      else
        scope.all # Organizations are generally viewable by all authenticated users
      end
    end
  end
end
