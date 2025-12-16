class OrganizationPolicy < ApplicationPolicy
  def show?
    admin_bypass? || true # Anyone can view organization details
  end

  def manage_employment?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end
  
  def create_employment?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_create_employment?
  end

  def manage_maap?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_maap?
  end

  def create?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def update?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def destroy?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def check_ins_health?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def view_prompts?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_observations?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_seats?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    return false unless viewing_teammate.employed?
    admin_bypass? || true
  end

  def view_goals?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_abilities?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_assignments?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_aspirations?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_prompt_templates?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || viewing_teammate.can_manage_prompts?
  end

  def view_bulk_sync_events?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_search?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  private

  def organization_in_hierarchy?
    return false unless viewing_teammate
    teammate_org = viewing_teammate.organization
    return false unless teammate_org
    
    # Check if record is the teammate's organization or in its hierarchy
    record == teammate_org || teammate_org.self_and_descendants.include?(record)
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
