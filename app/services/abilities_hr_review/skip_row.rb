# frozen_string_literal: true

module AbilitiesHrReview
  class SkipRow
    def self.call(bulk_sync_event:, row_id:)
      new(bulk_sync_event: bulk_sync_event, row_id: row_id).call
    end

    def initialize(bulk_sync_event:, row_id:)
      @event = bulk_sync_event
      @row_id = row_id.to_s
    end

    def call
      return Result.err('Invalid bulk sync event type') unless @event.is_a?(BulkSyncEvent::UploadAbilitiesHrReview)

      rows = Array(@event.preview_actions&.dig('rows'))
      idx = rows.index { |r| r['id'].to_s == @row_id }
      return Result.err('Row not found') unless idx

      row = rows[idx]
      return Result.err('Row already applied') if row['state'] == 'applied'

      rows[idx] = row.merge('state' => 'skipped')
      @event.update!(preview_actions: @event.preview_actions.merge('rows' => rows))
      BulkSyncEvent::UploadAbilitiesHrReview.mark_completed_if_done!(@event.reload)
      Result.ok(true)
    end
  end
end
