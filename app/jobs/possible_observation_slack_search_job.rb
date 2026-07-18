# frozen_string_literal: true

class PossibleObservationSlackSearchJob < ApplicationJob
  queue_as :default

  def perform(possible_observation_slack_search_id)
    search = PossibleObservationSlackSearch.find_by(id: possible_observation_slack_search_id)
    return if search.nil?
    return if search.search_status == "completed"

    result = PossibleObservationSlackSearches::RunSearchService.call(search: search)
    return unless result.success?

    search.reload
    return unless search.auto_extract_after_search?

    search.message_batches.find_each do |batch|
      next unless batch.extraction_status == "ready"

      batch.update!(extraction_status: "pending", extraction_error: nil, extractions: {})
      PossibleObservationSlackSearchExtractionJob.perform_later(batch.id)
    end
  end
end
