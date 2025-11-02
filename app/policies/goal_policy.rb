class GoalPolicy < ApplicationPolicy
  def index?
    admin_bypass? || user_is_teammate?
  end

  def show?
    admin_bypass? || record.can_be_viewed_by?(actual_user)
  end

  def create?
    admin_bypass? || user_is_teammate?
  end

  def update?
    admin_bypass? || user_is_creator_or_owner?
  end

  def destroy?
    admin_bypass? || user_is_creator?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if actual_user.og_admin?
        scope.all
      elsif user.respond_to?(:pundit_organization) && user.pundit_organization
        # Get all teammates for the current person in the organization context
        teammates = actual_user.teammates.where(organization: user.pundit_organization)
        scope.for_teammate(teammates)
      else
        # Fallback: get all teammates for current person
        teammates = actual_user.teammates
        scope.for_teammate(teammates)
      end
    end
  end

  private

  def user_is_teammate?
    return false unless user.respond_to?(:pundit_organization) && user.pundit_organization
    
    actual_user.teammates.exists?(organization: user.pundit_organization)
  end

  def user_is_creator?
    return false unless record&.creator
    
    actual_user == record.creator.person
  end

  def user_is_creator_or_owner?
    return false unless record
    
    # User is creator
    return true if user_is_creator?
    
    # User is owner (if owner is Person)
    if record.owner_type == 'Person' && record.owner_id == actual_user.id
      return true
    end
    
    false
  end
end


