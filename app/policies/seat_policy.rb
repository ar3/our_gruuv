class SeatPolicy < ApplicationPolicy
  def index?
    return false unless viewing_teammate
    # For index, check against organization from viewing_teammate
    organization = actual_organization
    return false unless organization
    return false unless organization == viewing_teammate.organization
    person = viewing_teammate.person
    person.active_employment_tenure_in?(organization) || viewing_teammate.can_manage_maap?
  end

  def show?
    return false unless viewing_teammate
    org = record&.position_type&.organization
    return false unless org
    person = viewing_teammate.person
    person.active_employment_tenure_in?(org) || policy(org).manage_maap?
  end

  def create?
    return false unless viewing_teammate
    # For create, check against organization from viewing_teammate
    organization = actual_organization
    return false unless organization
    return false unless organization == viewing_teammate.organization
    viewing_teammate.can_manage_maap?
  end

  def update?
    return false unless viewing_teammate
    org = record&.position_type&.organization
    return false unless org
    policy(org).manage_maap?
  end

  def destroy?
    return false unless viewing_teammate
    org = record&.position_type&.organization
    return false unless org
    policy(org).manage_maap?
  end

  def reconcile?
    return false unless viewing_teammate
    org = record&.position_type&.organization
    return false unless org
    policy(org).manage_maap?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      # Get organization from viewing_teammate
      organization = actual_organization
      return scope.none unless organization
      return scope.none unless organization == viewing_teammate.organization
      
      person = viewing_teammate.person
      # The scope is already filtered by organization via Seat.for_organization
      seats_in_org = scope
      
      if viewing_teammate.can_manage_maap?
        seats_in_org
      elsif person.active_employment_tenure_in?(organization)
        seats_in_org.where(state: [:open, :filled])
      else
        scope.none
      end
    end
  end
end
