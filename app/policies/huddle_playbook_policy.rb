class HuddlePlaybookPolicy < ApplicationPolicy
  def show?
    admin_bypass? || true
  end

  def create?
    admin_bypass? || user.can_manage_employment?(record.organization)
  end

  def update?
    admin_bypass? || user.can_manage_employment?(record.organization)
  end

  def destroy?
    admin_bypass? || user.can_manage_employment?(record.organization)
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.all # Huddle playbooks are generally viewable by all authenticated users
      end
    end
  end
end
