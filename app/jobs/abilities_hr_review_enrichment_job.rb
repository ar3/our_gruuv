# frozen_string_literal: true

class AbilitiesHrReviewEnrichmentJob < ApplicationJob
  queue_as :default

  def perform(bulk_sync_event_id)
    event = BulkSyncEvent.find_by(id: bulk_sync_event_id)
    return unless event.is_a?(BulkSyncEvent::UploadAbilitiesHrReview)

    rows = Array(event.preview_actions&.dig('rows'))
    return if rows.empty?

    updated = rows.map do |row|
      next row if row['state'].to_s != 'pending'

      Llm::AbilitiesHrReviewEnricher.enrich_row(row)
    end

    preview = event.preview_actions.merge('rows' => updated, 'enrichment' => { 'status' => 'complete', 'at' => Time.current.iso8601 })
    event.update!(preview_actions: preview)
  end
end
