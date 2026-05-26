# frozen_string_literal: true

module AbilitiesHrReview
  class SkipAbilityGroup
    def self.call(bulk_sync_event:, ability_group_id:)
      new(bulk_sync_event: bulk_sync_event, ability_group_id: ability_group_id).call
    end

    def initialize(bulk_sync_event:, ability_group_id:)
      @event = bulk_sync_event
      @ability_group_id = ability_group_id.to_s
    end

    def call
      return Result.err('Invalid bulk sync event type') unless @event.is_a?(BulkSyncEvent::UploadAbilitiesHrReview)

      preview = @event.preview_actions.deep_stringify_keys
      groups = Array(preview['ability_groups'])
      idx = groups.index { |g| g['id'].to_s == @ability_group_id }
      return Result.err('Ability group not found') unless idx

      group = groups[idx]
      return Result.err('Ability group is invalid') if group['state'] == 'invalid'
      return Result.err('Ability group already applied') if group['state'] == 'applied'
      return Result.err('Ability group was skipped') if group['state'] == 'skipped'

      groups[idx] = group.merge('state' => 'skipped')

      associations = Array(preview['association_rows']).map do |row|
        next row unless row['ability_group_id'].to_s == @ability_group_id
        next row if row['state'] != 'pending'

        row.merge('state' => 'skipped', 'skipped_reason' => 'ability_skipped')
      end

      @event.update!(
        preview_actions: preview.merge('ability_groups' => groups, 'association_rows' => associations)
      )

      Result.ok(true)
    end
  end
end
