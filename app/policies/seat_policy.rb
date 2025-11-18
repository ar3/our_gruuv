class SeatPolicy < ApplicationPolicy
  def index?
    return false unless viewing_teammate
    # For index, check against organization from viewing_teammate
    organization = actual_organization
    return false unless organization
    person = viewing_teammate.person
    person.active_employment_tenure_in?(organization) || person.can_manage_maap?(organization)
  end

  def show?
    return false unless viewing_teammate
    person = viewing_teammate.person
    person.active_employment_tenure_in?(record&.position_type&.organization) || person.can_manage_maap?(record&.position_type&.organization)
  end

  def create?
    return false unless viewing_teammate
    # For create, check against organization from viewing_teammate
    organization = actual_organization
    return false unless organization
    person = viewing_teammate.person
    person.can_manage_maap?(organization)
  end

  def update?
    return false unless viewing_teammate
    person = viewing_teammate.person
    person.can_manage_maap?(record&.position_type&.organization)
  end

  def destroy?
    return false unless viewing_teammate
    person = viewing_teammate.person
    person.can_manage_maap?(record&.position_type&.organization)
  end

  def reconcile?
    return false unless viewing_teammate
    person = viewing_teammate.person
    person.can_manage_maap?(record&.position_type&.organization)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      # Get organization from viewing_teammate
      organization = actual_organization
      return scope.none unless organization
      
      person = viewing_teammate.person
      # The scope is already filtered by organization via Seat.for_organization
      seats_in_org = scope
      
      if person.can_manage_maap?(organization)
        seats_in_org
      elsif person.active_employment_tenure_in?(organization)
        seats_in_org.where(state: [:open, :filled])
      else
        scope.none
      end
    end
  end
end
