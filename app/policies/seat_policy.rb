class SeatPolicy < ApplicationPolicy
  def index?
    return false unless viewing_teammate
    return false unless viewing_teammate.employed?
    # For index, the record is the Seat class, so we can't get organization from record
    # The scope will verify organization matching, so just check teammate is active
    true
  end

  def show?
    return false unless viewing_teammate
    return false unless viewing_teammate.employed?
    org = record&.position_type&.organization
    return false unless org
    # Check if company_teammate matches root_company of the seat's organization
    seat_root_company = org.root_company
    return false unless seat_root_company
    viewing_teammate.organization == seat_root_company
  end

  def create?
    return false unless viewing_teammate
    return false unless viewing_teammate.employed?
    return false unless viewing_teammate.can_manage_maap?
    # For create, check against organization from viewing_teammate
    organization = actual_organization
    return false unless organization
    # Check if company_teammate matches root_company of the organization
    seat_root_company = organization.root_company
    return false unless seat_root_company
    viewing_teammate.organization == seat_root_company
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  def reconcile?
    create?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if viewing_teammate.nil?
      return scope.none if !viewing_teammate.employed?
      return scope.none if !scope.exists?
      
      # The scope is already filtered by organization via Seat.for_organization
      if viewing_teammate.can_manage_maap?
        scope
      else
        scope.where(state: [:open, :filled])
      end
    end
  end
end
