class HuddlePlaybookPolicy < ApplicationPolicy
  def show?
    admin_bypass? || true
  end

  def create?
    return false unless viewing_teammate
    person = viewing_teammate.person
    admin_bypass? || person.can_manage_employment?(record.organization)
  end

  def update?
    return false unless viewing_teammate
    person = viewing_teammate.person
    admin_bypass? || person.can_manage_employment?(record.organization)
  end

  def destroy?
    return false unless viewing_teammate
    person = viewing_teammate.person
    admin_bypass? || person.can_manage_employment?(record.organization)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person&.admin?
        scope.all
      else
        scope.all # Huddle playbooks are generally viewable by all authenticated users
      end
    end
  end
end
