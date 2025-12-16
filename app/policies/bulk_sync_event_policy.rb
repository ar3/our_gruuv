class BulkSyncEventPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    return false unless record.is_a?(BulkSyncEvent)
    return false unless record.organization == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def create?
    return false unless viewing_teammate
    # For class-level authorization, check if user can manage employment in their current organization
    # The base controller ensures viewing_teammate matches the route organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def destroy?
    return false unless viewing_teammate
    return false unless record.is_a?(BulkSyncEvent)
    return false unless record.organization == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def process_sync?
    return false unless viewing_teammate
    return false unless record.is_a?(BulkSyncEvent)
    return false unless record.organization == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person&.og_admin?
        scope.all
      else
        # Only show bulk sync events for organizations where user can manage employment
        organization_ids = person.teammates.where(can_manage_employment: true).pluck(:organization_id)
        scope.where(organization_id: organization_ids)
      end
    end
  end
end
