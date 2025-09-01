class SeatPolicy < ApplicationPolicy
  def index?
    # For index, check against organization from context
    organization = record.context[:organization]
    user.active_employment_tenure_in?(organization) || user.can_manage_maap?(organization)
  end

  def show?
    user.active_employment_tenure_in?(record&.position_type&.organization) || user.can_manage_maap?(record&.position_type&.organization)
  end

  def create?
    # For create, check against organization from context
    organization = record.context[:organization]
    user.can_manage_maap?(organization)
  end

  def update?
    user.can_manage_maap?(record&.position_type&.organization)
  end

  def destroy?
    user.can_manage_maap?(record&.position_type&.organization)
  end

  def reconcile?
    user.can_manage_maap?(record&.position_type&.organization)
  end

  class Scope < Scope
    def resolve
      # Get organization from context (passed by controller)
      organization = scope.context[:organization]
      
      # Filter seats by organization context
      seats_in_org = scope.for_organization(organization)
      
      if user.can_manage_maap?(organization)
        seats_in_org
      elsif user.active_employment_tenure_in?(organization)
        seats_in_org.where(state: [:open, :filled])
      else
        scope.none
      end
    end
  end
end
