class PositionTypePolicy < ApplicationPolicy
  def show?
    admin_bypass? || user_has_maap_permission_for_record?
  end

  def create?
    admin_bypass? || user_has_maap_permission?
  end

  def update?
    admin_bypass? || user_has_maap_permission_for_record?
  end

  def destroy?
    admin_bypass? || user_has_maap_permission_for_record?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person&.og_admin?
        scope.all
      else
        viewing_teammate_org = viewing_teammate.organization
        return scope.none unless viewing_teammate_org
        
        if viewing_teammate.can_manage_maap?
          # Include position types from viewing_teammate's organization and all its descendants
          # This allows viewing department position types when signed in to company
          org_ids = viewing_teammate_org.self_and_descendants.map(&:id)
          scope.where(organization_id: org_ids)
        else
          scope.none
        end
      end
    end
  end

  private

  def user_has_maap_permission?
    return false unless viewing_teammate
    organization = actual_organization
    return false unless organization
    
    viewing_teammate.can_manage_maap?
  end

  def user_has_maap_permission_for_record?
    return false unless viewing_teammate
    return false unless record&.organization
    viewing_teammate_org = viewing_teammate.organization
    return false unless viewing_teammate_org
    
    # Check if record's organization is in viewing_teammate's organization hierarchy
    orgs = viewing_teammate_org.self_and_descendants
    return false unless orgs.include?(record.organization)
    
    viewing_teammate.can_manage_maap?
  end
end


