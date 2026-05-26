# frozen_string_literal: true

module AbilitiesHrReview
  class SkipAssociationRow
    def self.call(bulk_sync_event:, association_row_id:)
      new(bulk_sync_event: bulk_sync_event, association_row_id: association_row_id).call
    end

    def initialize(bulk_sync_event:, association_row_id:)
      @event = bulk_sync_event
      @association_row_id = association_row_id.to_s
    end

    def call
      return Result.err('Invalid bulk sync event type') unless @event.is_a?(BulkSyncEvent::UploadAbilitiesHrReview)

      preview = @event.preview_actions.deep_stringify_keys
      associations = Array(preview['association_rows'])
      idx = associations.index { |r| r['id'].to_s == @association_row_id }
      return Result.err('Association row not found') unless idx

      row = associations[idx]
      return Result.err('Association row already applied') if row['state'] == 'applied'

      associations[idx] = row.merge('state' => 'skipped', 'skipped_reason' => 'user_skipped')
      @event.update!(preview_actions: preview.merge('association_rows' => associations))

      BulkSyncEvent::UploadAbilitiesHrReview.mark_completed_if_done!(@event.reload)

      Result.ok(true)
    end
  end
end
