# frozen_string_literal: true

class PossibleObservationTranscriptPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization_id: viewing_teammate.organization_id)
    end
  end

  def index?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?

    true
  end

  def show?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?

    admin_bypass? || record.creator_company_teammate_id == viewing_teammate.id
  end

  def create?
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?

    true
  end

  def update?
    show?
  end

  def destroy?
    show? && record.deletable?
  end

  def batch_create_feedback_requests?
    show?
  end

  def re_extract?
    show?
  end
end
