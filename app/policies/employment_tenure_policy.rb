class EmploymentTenurePolicy < ApplicationPolicy
  def index?
    admin_bypass?
  end

  def show?
    admin_bypass? || record.person == actual_user
  end

  def create?
    admin_bypass? || record.person == actual_user
  end

  def new?
    # For new action, we need to check if user can create for the person in the URL
    # This will be handled in the controller by passing the person context
    admin_bypass? || actual_user == @person
  end

  def update?
    admin_bypass? || record.person == actual_user
  end

  def destroy?
    admin_bypass? || record.person == actual_user
  end

  def change?
    admin_bypass? || record.person == actual_user
  end

  def add_history?
    admin_bypass?
  end

  def employment_summary?
    admin_bypass? || record.person == actual_user
  end

  class Scope < Scope
    def resolve
      if actual_user&.admin?
        scope.all
      else
        scope.where(person: actual_user)
      end
    end
  end
end
