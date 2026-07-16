# frozen_string_literal: true

class PossibleObservationSlackSearchJob < ApplicationJob
  queue_as :default

  def perform(possible_observation_slack_search_id)
    search = PossibleObservationSlackSearch.find_by(id: possible_observation_slack_search_id)
    return if search.nil?
    return if search.search_status == "completed"

    PossibleObservationSlackSearches::RunSearchService.call(search: search)
  end
end
