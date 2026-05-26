# frozen_string_literal: true

module AbilitiesHrReview
  # Runs Markdown cleanup + AI similarity matching for all pending ability groups.
  class EnrichPreview
    def self.call(bulk_sync_event:)
      new(bulk_sync_event: bulk_sync_event).call
    end

    def initialize(bulk_sync_event:)
      @event = bulk_sync_event
    end

    def call
      return false unless @event.is_a?(BulkSyncEvent::UploadAbilitiesHrReview)

      preview = @event.preview_actions.is_a?(Hash) ? @event.preview_actions.deep_stringify_keys : {}
      groups = Array(preview['ability_groups'])
      return false if groups.empty?

      organization = @event.organization
      updated = groups.map do |group|
        next group unless group['state'].to_s == 'pending'
        next group if group['enrichment_status'].to_s == 'complete'
        next group if group['state'].to_s == 'invalid'

        if group['ability_match_kind'].to_s == 'exact_insensitive'
          next group.merge('enrichment_status' => 'complete')
        end

        Llm::AbilitiesHrReviewEnricher.enrich_group(group, organization: organization)
      end

      preview = preview.merge(
        'ability_groups' => updated,
        'enrichment' => { 'status' => 'complete', 'at' => Time.current.iso8601 }
      )
      @event.update!(preview_actions: preview)
      true
    end
  end
end
