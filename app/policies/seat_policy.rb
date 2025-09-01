class SeatPolicy < ApplicationPolicy
  def index?
    # For index, check against organization from pundit_user
    organization = user.pundit_organization
    return false unless organization
    actual_user.active_employment_tenure_in?(organization) || actual_user.can_manage_maap?(organization)
  end

  def show?
    actual_user.active_employment_tenure_in?(record&.position_type&.organization) || actual_user.can_manage_maap?(record&.position_type&.organization)
  end

  def create?
    # For create, check against organization from pundit_user
    organization = user.pundit_organization
    return false unless organization
    actual_user.can_manage_maap?(organization)
  end

  def update?
    actual_user.can_manage_maap?(record&.position_type&.organization)
  end

  def destroy?
    actual_user.can_manage_maap?(record&.position_type&.organization)
  end

  def reconcile?
    actual_user.can_manage_maap?(record&.position_type&.organization)
  end

  class Scope < Scope
    def resolve
      # Get organization from pundit_user
      organization = user.pundit_organization
      return scope.none unless organization
      
      # The scope is already filtered by organization via Seat.for_organization
      seats_in_org = scope
      
      if actual_user.can_manage_maap?(organization)
        seats_in_org
      elsif actual_user.active_employment_tenure_in?(organization)
        seats_in_org.where(state: [:open, :filled])
      else
        scope.none
      end
    end
  end
end
