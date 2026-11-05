# frozen_string_literal: true

class PossibleObservationSlackSearchPolicy < ApplicationPolicy
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
    return false unless viewing_teammate.has_slack_search_identity?

    true
  end

  def destroy?
    show? && record.deletable?
  end

  def update?
    show?
  end

  def extraction_status?
    show?
  end

  # Re-run LLM extract on this search's stored messages (e.g. after a prompt bump).
  def re_consult?
    show? &&
      record.search_status == "completed" &&
      !record.hub_in_flight? &&
      record.extractable_batches.any?
  end
end
