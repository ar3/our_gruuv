class AbilityPolicy < ApplicationPolicy
  def index?
    admin_bypass? || user_has_maap_permission?
  end

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
      return scope.none unless teammate
      person = teammate.person
      if person&.og_admin?
        scope.all
      else
        teammate_org = teammate.organization
        return scope.none unless teammate_org
        
        if teammate.can_manage_maap?
          # Include abilities from teammate's organization and all its descendants
          # This allows viewing department abilities when signed in to company
          org_ids = teammate_org.self_and_descendants.map(&:id)
          scope.where(organization_id: org_ids)
        else
          scope.none
        end
      end
    end
  end

  private

  def user_has_maap_permission?
    return false unless teammate
    organization = actual_organization
    return false unless organization
    
    teammate.can_manage_maap?
  end

  def user_has_maap_permission_for_record?
    return false unless teammate
    return false unless record&.organization
    teammate_org = teammate.organization
    return false unless teammate_org
    
    # Check if record's organization is in teammate's organization hierarchy
    orgs = teammate_org.self_and_descendants
    return false unless orgs.include?(record.organization)
    
    teammate.can_manage_maap?
  end
end
