class HuddlePlaybookPolicy < ApplicationPolicy
  def show?
    admin_bypass? || true
  end

  def create?
    return false unless viewing_teammate
    return false unless record.organization
    admin_bypass? || policy(record.organization).manage_employment?
  end

  def update?
    return false unless viewing_teammate
    return false unless record.organization
    admin_bypass? || policy(record.organization).manage_employment?
  end

  def destroy?
    return false unless viewing_teammate
    return false unless record.organization
    admin_bypass? || policy(record.organization).manage_employment?
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
