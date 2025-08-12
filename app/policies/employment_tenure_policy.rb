class EmploymentTenurePolicy < ApplicationPolicy
  def index?
    user.admin?
  end

  def show?
    user.admin? || record.person == user
  end

  def create?
    user.admin? || record.person == user
  end

  def new?
    # For new action, we need to check if user can create for the person in the URL
    # This will be handled in the controller by passing the person context
    user.admin? || user == @person
  end

  def update?
    user.admin? || record.person == user
  end

  def destroy?
    user.admin? || record.person == user
  end

  def change?
    user.admin? || record.person == user
  end

  def add_history?
    user.admin?
  end

  def employment_summary?
    user.admin? || record.person == user
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(person: user)
      end
    end
  end
end
