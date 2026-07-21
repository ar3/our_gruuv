# frozen_string_literal: true

class PossibleObservationSlackSearchBatchPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:possible_observation_slack_search)
           .where(possible_observation_slack_searches: { organization_id: viewing_teammate.organization_id })
    end
  end

  def show?
    search_policy.show?
  end

  def update?
    show?
  end

  def extract?
    show? && record.possible_observation_slack_search.search_status == "completed" &&
      %w[ready failed completed].include?(record.extraction_status)
  end

  def re_extract?
    extract?
  end

  def extraction_status?
    show?
  end

  def create_draft_observations?
    update? && record.extraction_status == "completed"
  end

  private

  def search_policy
    PossibleObservationSlackSearchPolicy.new(pundit_user, record.possible_observation_slack_search)
  end
end
