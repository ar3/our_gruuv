class PromptQuestionPolicy < ApplicationPolicy
  def create?
    admin_bypass? || user_has_prompts_permission_for_template?
  end

  def update?
    admin_bypass? || user_has_prompts_permission_for_template?
  end

  def destroy?
    admin_bypass? || user_has_prompts_permission_for_template?
  end

  def archive?
    update?
  end

  def unarchive?
    update?
  end

  private

  def user_has_prompts_permission_for_template?
    return false unless viewing_teammate
    return false unless record&.prompt_template&.company
    
    viewing_teammate_org = viewing_teammate.organization
    return false unless viewing_teammate_org
    
    # Check if template's company matches viewing_teammate's root company
    root_company = viewing_teammate_org.root_company || viewing_teammate_org
    return false unless root_company.id == record.prompt_template.company_id
    
    viewing_teammate.can_manage_prompts?
  end
end


