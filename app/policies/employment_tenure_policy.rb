class EmploymentTenurePolicy < ApplicationPolicy
  def index?
    admin_bypass?
  end

  def show?
    return false unless teammate
    person = teammate.person
    admin_bypass? || record.teammate.person == person
  end

  def create?
    return false unless teammate
    person = teammate.person
    admin_bypass? || record.teammate.person == person
  end

  def new?
    # For new action, we need to check if user can create for the person in the URL
    # This will be handled in the controller by passing the person context
    return false unless teammate
    person = teammate.person
    admin_bypass? || person == @person
  end

  def update?
    return false unless teammate
    person = teammate.person
    admin_bypass? || record.teammate.person == person
  end

  def destroy?
    return false unless teammate
    person = teammate.person
    admin_bypass? || record.teammate.person == person
  end

  def change?
    return false unless teammate
    person = teammate.person
    admin_bypass? || record.teammate.person == person
  end

  def add_history?
    admin_bypass?
  end

  def employment_summary?
    return false unless teammate
    person = teammate.person
    admin_bypass? || record.teammate.person == person
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless teammate
      person = teammate.person
      if person&.admin?
        scope.all
      else
        scope.joins(:teammate).where(teammates: { person: person })
      end
    end
  end
end
