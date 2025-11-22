class PromptGoalPolicy < ApplicationPolicy
  def create?
    return false unless record&.prompt
    return true if admin_bypass?
    return false unless viewing_teammate && record.prompt
    
    # Same authorization as PromptPolicy#update?
    prompt_policy = PromptPolicy.new(pundit_user, record.prompt)
    prompt_policy.update?
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

