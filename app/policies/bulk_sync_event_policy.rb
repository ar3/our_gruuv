class BulkSyncEventPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    return false unless record.is_a?(BulkSyncEvent)
    return false unless record.organization == viewing_teammate.organization
    admin_bypass? || (requires_maap_permission?(record) ? viewing_teammate.can_manage_maap? : viewing_teammate.can_manage_employment?)
  end

  def create?
    return false unless viewing_teammate
    # For class-level authorization, allow if user has either employment or maap permission
    # The specific type will be checked when the instance is created
    # For instance-level (when record is an instance), check the specific type
    if record.is_a?(Class)
      # Class-level: allow if user has either permission
      admin_bypass? || viewing_teammate.can_manage_employment? || viewing_teammate.can_manage_maap?
    elsif record.is_a?(BulkSyncEvent) && requires_maap_permission?(record)
      # Instance-level: check specific type
      admin_bypass? || viewing_teammate.can_manage_maap?
    else
      # Instance-level: default to employment permission
      admin_bypass? || viewing_teammate.can_manage_employment?
    end
  end

  def destroy?
    return false unless viewing_teammate
    return false unless record.is_a?(BulkSyncEvent)
    return false unless record.organization == viewing_teammate.organization
    admin_bypass? || (requires_maap_permission?(record) ? viewing_teammate.can_manage_maap? : viewing_teammate.can_manage_employment?)
  end

  def process_sync?
    return false unless viewing_teammate
    return false unless record.is_a?(BulkSyncEvent)
    return false unless record.organization == viewing_teammate.organization
    admin_bypass? || (requires_maap_permission?(record) ? viewing_teammate.can_manage_maap? : viewing_teammate.can_manage_employment?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person&.og_admin?
        scope.all
      else
        # Include bulk sync events where user can manage employment OR maap
        employment_org_ids = person.teammates.where(can_manage_employment: true).pluck(:organization_id)
        maap_org_ids = person.teammates.where(can_manage_maap: true).pluck(:organization_id)
        organization_ids = (employment_org_ids + maap_org_ids).uniq
        scope.where(organization_id: organization_ids)
      end
    end
  end

  private

  def requires_maap_permission?(record)
    record.is_a?(BulkSyncEvent::UploadAssignmentsAndAbilities)
  end
end
