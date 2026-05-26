# frozen_string_literal: true

class AbilitiesHrReviewEnrichmentJob < ApplicationJob
  queue_as :default

  def perform(bulk_sync_event_id)
    event = BulkSyncEvent.find_by(id: bulk_sync_event_id)
    return unless event

    AbilitiesHrReview::EnrichPreview.call(bulk_sync_event: event)
  end
end
