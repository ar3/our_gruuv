class OrganizationPolicy < ApplicationPolicy
  def show?
    admin_bypass? || true # Anyone can view organization details
  end

  def manage_employment?
    return false unless viewing_teammate
    person = viewing_teammate.person
    admin_bypass? || (person && person.can_manage_employment?(record))
  end
  
  def create_employment?
    return false unless viewing_teammate
    person = viewing_teammate.person
    admin_bypass? || (person && person.can_create_employment?(record))
  end

  def manage_maap?
    return false unless viewing_teammate
    person = viewing_teammate.person
    admin_bypass? || (person && person.can_manage_maap?(record))
  end

  def create?
    return false unless viewing_teammate
    person = viewing_teammate.person
    admin_bypass? || (person && person.can_manage_employment?(record))
  end

  def update?
    return false unless viewing_teammate
    person = viewing_teammate.person
    admin_bypass? || (person && person.can_manage_employment?(record))
  end

  def destroy?
    return false unless viewing_teammate
    person = viewing_teammate.person
    admin_bypass? || (person && person.can_manage_employment?(record))
  end

  def check_ins_health?
    return false unless viewing_teammate
    person = viewing_teammate.person
    admin_bypass? || (person && person.can_manage_employment?(record))
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person&.admin?
        scope.all
      else
        scope.all # Organizations are generally viewable by all authenticated users
      end
    end
  end
end
