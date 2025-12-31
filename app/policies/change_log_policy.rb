class ChangeLogPolicy < ApplicationPolicy
  def index?
    # Public access
    true
  end

  def show?
    # Public access
    true
  end

  def new?
    # Admin only
    admin_bypass?
  end

  def create?
    # Admin only
    admin_bypass?
  end

  def edit?
    # Admin only
    admin_bypass?
  end

  def update?
    # Admin only
    admin_bypass?
  end

  def destroy?
    # Admin only
    admin_bypass?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Return all change logs (public)
      scope.all
    end
  end
end

