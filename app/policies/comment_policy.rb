class CommentPolicy < ApplicationPolicy
  def show?
    admin_bypass? || can_view_commentable?
  end

  def create?
    return false unless behavior.allows_comments?

    admin_bypass? || can_view_commentable?
  end

  def update?
    admin_bypass? || is_creator?
  end

  def destroy?
    return true if admin_bypass?

    behavior.destroy?(record, viewing_teammate)
  end

  def resolve?
    return false unless behavior.allows_resolve?

    admin_bypass? || is_creator?
  end

  def unresolve?
    return false unless behavior.allows_resolve?

    admin_bypass? || is_creator?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate

      if viewing_teammate.person&.og_admin?
        scope.all
      else
        viewing_teammate_org = viewing_teammate.organization
        return scope.none unless viewing_teammate_org

        org_ids = viewing_teammate_org.self_and_descendants.map(&:id)
        scope.where(organization_id: org_ids)
      end
    end
  end

  private

  def behavior
    @behavior ||= Comments::CommentableBehavior.for(record)
  end

  def can_view_commentable?
    return false unless viewing_teammate
    return false unless record&.commentable

    root = record.root_commentable
    return false unless root
    return false unless Comments::CommentableBehavior.for(root).supported?

    Pundit.policy(pundit_user, root).show?
  end

  def is_creator?
    return false unless viewing_teammate
    return false unless record&.creator

    viewing_teammate.person == record.creator
  end
end
