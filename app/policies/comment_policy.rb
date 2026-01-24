class CommentPolicy < ApplicationPolicy
  def show?
    admin_bypass? || can_view_commentable?
  end

  def create?
    admin_bypass? || can_view_commentable?
  end

  def update?
    admin_bypass? || is_creator?
  end

  def resolve?
    admin_bypass? || is_creator?
  end

  def unresolve?
    admin_bypass? || is_creator?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      
      if viewing_teammate.person&.og_admin?
        scope.all
      else
        # Filter by organization - user can see comments in their organization hierarchy
        viewing_teammate_org = viewing_teammate.organization
        return scope.none unless viewing_teammate_org
        
        org_ids = viewing_teammate_org.self_and_descendants.map(&:id)
        scope.where(organization_id: org_ids)
      end
    end
  end

  private

  def can_view_commentable?
    return false unless viewing_teammate
    return false unless record&.commentable
    
    commentable = record.commentable
    case commentable
    when Assignment
      Pundit.policy(pundit_user, commentable).show?
    when Ability
      Pundit.policy(pundit_user, commentable).show?
    when Aspiration
      Pundit.policy(pundit_user, commentable).show?
    when Position
      Pundit.policy(pundit_user, commentable).show?
    when Title
      Pundit.policy(pundit_user, commentable).show?
    when Comment
      # For nested comments, check if user can view the root commentable
      root = record.root_commentable
      return false unless root
      
      case root
      when Assignment
        Pundit.policy(pundit_user, root).show?
      when Ability
        Pundit.policy(pundit_user, root).show?
      when Aspiration
        Pundit.policy(pundit_user, root).show?
      when Position
        Pundit.policy(pundit_user, root).show?
      when Title
        Pundit.policy(pundit_user, root).show?
      else
        false
      end
    else
      false
    end
  end

  def is_creator?
    return false unless viewing_teammate
    return false unless record&.creator
    
    viewing_teammate.person == record.creator
  end
end
