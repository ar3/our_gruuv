class EmploymentTenurePolicy < ApplicationPolicy
  def index?
    admin_bypass?
  end

  def show?
    admin_bypass? || record.person == user
  end

  def create?
    admin_bypass? || record.person == user
  end

  def new?
    # For new action, we need to check if user can create for the person in the URL
    # This will be handled in the controller by passing the person context
    admin_bypass? || user == @person
  end

  def update?
    admin_bypass? || record.person == user
  end

  def destroy?
    admin_bypass? || record.person == user
  end

  def change?
    admin_bypass? || record.person == user
  end

  def add_history?
    admin_bypass?
  end

  def employment_summary?
    admin_bypass? || record.person == user
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.where(person: user)
      end
    end
  end
end
