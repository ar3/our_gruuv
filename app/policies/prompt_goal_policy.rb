class PromptGoalPolicy < ApplicationPolicy
  def create?
    return false unless record&.prompt
    return true if admin_bypass?
    return false unless viewing_teammate && record.prompt
    
    # Same authorization as PromptPolicy#show? (owner, can_manage_prompts, or in managerial hierarchy can link goals)
    prompt_policy = PromptPolicy.new(pundit_user, record.prompt)
    prompt_policy.show?
  end

  def destroy?
    create? # Same authorization as create
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # PromptGoals are scoped through their prompts
      # Use PromptPolicy::Scope to get accessible prompts, then get their goals
      accessible_prompts = PromptPolicy::Scope.new(pundit_user, Prompt.all).resolve
      scope.where(prompt_id: accessible_prompts.pluck(:id))
    end
  end
end


