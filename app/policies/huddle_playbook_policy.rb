class HuddlePlaybookPolicy < ApplicationPolicy
  def show?
    admin_bypass? || true
  end

  def create?
    return false unless teammate
    person = teammate.person
    admin_bypass? || person.can_manage_employment?(record.organization)
  end

  def update?
    return false unless teammate
    person = teammate.person
    admin_bypass? || person.can_manage_employment?(record.organization)
  end

  def destroy?
    return false unless teammate
    person = teammate.person
    admin_bypass? || person.can_manage_employment?(record.organization)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless teammate
      person = teammate.person
      if person&.admin?
        scope.all
      else
        scope.all # Huddle playbooks are generally viewable by all authenticated users
      end
    end
  end
end
