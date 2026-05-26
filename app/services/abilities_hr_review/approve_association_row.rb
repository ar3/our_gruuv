# frozen_string_literal: true

module AbilitiesHrReview
  # Links an approved ability to an assignment with a milestone level.
  class ApproveAssociationRow
    def self.call(bulk_sync_event:, association_row_id:, person:, overrides: {})
      new(
        bulk_sync_event: bulk_sync_event,
        association_row_id: association_row_id,
        person: person,
        overrides: overrides.stringify_keys
      ).call
    end

    def initialize(bulk_sync_event:, association_row_id:, person:, overrides: {})
      @event = bulk_sync_event
      @association_row_id = association_row_id.to_s
      @person = person
      @overrides = overrides
    end

    def call
      unless @event.is_a?(BulkSyncEvent::UploadAbilitiesHrReview)
        return Result.err('Invalid bulk sync event type')
      end

      preview = @event.preview_actions.deep_stringify_keys
      associations = Array(preview['association_rows'])
      idx = associations.index { |r| r['id'].to_s == @association_row_id }
      return Result.err('Association row not found') unless idx

      row = associations[idx]
      return Result.err('Association row already applied') if row['state'] == 'applied'
      return Result.err('Association row was skipped') if row['state'] == 'skipped'

      groups = Array(preview['ability_groups'])
      group = groups.find { |g| g['id'].to_s == row['ability_group_id'].to_s }
      return Result.err('Ability group not found') unless group
      return Result.err('Ability was not approved') unless group['state'] == 'applied'

      ability_id = group['applied_ability_id']
      return Result.err('Approved ability is missing') if ability_id.blank?

      ability = Ability.find_by(id: ability_id, company_id: @event.organization_id)
      return Result.err('Ability not found') unless ability

      assignment_id = (@overrides['resolved_assignment_id'].presence || row['resolved_assignment_id']).to_i
      assignment = Assignment.find_by(id: assignment_id, company_id: @event.organization_id)
      return Result.err('Assignment not found or not in this organization') unless assignment

      join_level = (@overrides['join_milestone_level'].presence || row.dig('join_milestone', 'level')).to_i
      join_level = 1 unless (1..5).cover?(join_level)

      ApplicationRecord.transaction do
        aa = AssignmentAbility.find_or_initialize_by(assignment: assignment, ability: ability)
        aa.milestone_level = join_level
        aa.save!
      end

      row = row.merge(
        'state' => 'applied',
        'resolved_assignment_id' => assignment.id,
        'join_milestone' => (row['join_milestone'] || {}).stringify_keys.merge('level' => join_level),
        'apply_error' => nil
      )
      associations[idx] = row

      groups = refresh_group_associations(groups, group, ability)

      results = append_result_success(ability, assignment, join_level, group)
      merged_preview = preview.merge('ability_groups' => groups, 'association_rows' => associations)
      @event.update!(preview_actions: merged_preview, results: results)

      BulkSyncEvent::UploadAbilitiesHrReview.mark_completed_if_done!(@event)

      Result.ok(ability: ability, assignment: assignment)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(', '))
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    def refresh_group_associations(groups, group, ability)
      group_idx = groups.index { |g| g['id'].to_s == group['id'].to_s }
      return groups unless group_idx

      groups[group_idx] = group.merge(
        'existing_associations' => ExistingAssociations.list(
          organization: @event.organization,
          ability_id: ability.id
        )
      )
      groups
    end

    def append_result_success(ability, assignment, join_level, group)
      @event.reload
      results = @event.results.is_a?(Hash) ? @event.results.deep_stringify_keys : { 'successes' => [], 'failures' => [] }
      results['successes'] ||= []
      results['successes'] << {
        'type' => 'ability_association_import',
        'ability_id' => ability.id,
        'assignment_id' => assignment.id,
        'ability_name' => ability.name,
        'assignment_title' => assignment.title,
        'milestone_level' => join_level,
        'ability_action' => group['ability_action']
      }
      results
    end
  end
end
