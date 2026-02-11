class PromptTemplatePolicy < ApplicationPolicy
  def show?
    admin_bypass? || user_has_prompts_permission_for_record?
  end

  def create?
    admin_bypass? || user_has_prompts_permission?
  end

  def update?
    admin_bypass? || user_has_prompts_permission_for_record?
  end

  def destroy?
    admin_bypass? || user_has_prompts_permission_for_record?
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
        return scope.none unless viewing_teammate.employed?

        # Any active teammate in hierarchy can see company templates (for index); create/update/destroy are gated by action policies
        root_company = viewing_teammate_org.root_company || viewing_teammate_org
        scope.where(company_id: root_company.id)
      end
    end
  end

  private

  def user_has_prompts_permission?
    return false unless viewing_teammate
    organization = actual_organization
    return false unless organization
    
    viewing_teammate.can_manage_prompts?
  end

  def user_has_prompts_permission_for_record?
    return false unless viewing_teammate
    return false unless record&.company
    viewing_teammate_org = viewing_teammate.organization
    return false unless viewing_teammate_org
    
    # Check if record's company matches viewing_teammate's root company
    root_company = viewing_teammate_org.root_company || viewing_teammate_org
    return false unless root_company.id == record.company_id
    
    viewing_teammate.can_manage_prompts?
  end
end

