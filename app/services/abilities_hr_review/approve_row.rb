# frozen_string_literal: true

module AbilitiesHrReview
  # Applies one preview row: creates Ability + AssignmentAbility; never updates Assignment.
  class ApproveRow
    def self.call(bulk_sync_event:, row_id:, person:, overrides: {})
      new(bulk_sync_event: bulk_sync_event, row_id: row_id, person: person, overrides: overrides).call
    end

    def initialize(bulk_sync_event:, row_id:, person:, overrides: {})
      @event = bulk_sync_event
      @row_id = row_id.to_s
      @person = person
      @overrides = overrides.stringify_keys
    end

    def call
      unless @event.is_a?(BulkSyncEvent::UploadAbilitiesHrReview)
        return Result.err('Invalid bulk sync event type')
      end

      rows = Array(@event.preview_actions&.dig('rows'))
      idx = rows.index { |r| r['id'].to_s == @row_id }
      return Result.err('Row not found') unless idx

      row = rows[idx]
      return Result.err('Row already applied') if row['state'] == 'applied'
      return Result.err('Row was skipped') if row['state'] == 'skipped'

      assignment_id = (@overrides['resolved_assignment_id'].presence || row['resolved_assignment_id']).to_i
      assignment = Assignment.find_by(id: assignment_id, company_id: @event.organization_id)
      return Result.err('Assignment not found or not in this organization') unless assignment

      name = (@overrides['ability_name'].presence || row['ability_name']).to_s.strip
      return Result.err('Ability name is required') if name.blank?

      description = pick_text(row['description'], @overrides['description'])
      return Result.err('Description is required') if description.blank?

      milestone_attrs = {}
      (1..5).each do |n|
        milestone_attrs["milestone_#{n}_description"] = pick_milestone_text(row, n, @overrides["milestone_#{n}_description"])
      end

      join_level = (@overrides['join_milestone_level'].presence || row.dig('join_milestone', 'level')).to_i
      join_level = 1 unless (1..5).cover?(join_level)

      ability = nil
      ApplicationRecord.transaction do
        ability = Ability.new(
          company_id: @event.organization_id,
          name: name,
          description: description,
          created_by: @person,
          updated_by: @person,
          department_id: (@overrides['department_id'].presence || assignment.department_id)
        )
        milestone_attrs.each { |attr, val| ability[attr] = val }

        ability.save!
        AssignmentAbility.create!(
          assignment: assignment,
          ability: ability,
          milestone_level: join_level
        )
      end

      row = row.merge(
        'state' => 'applied',
        'applied_ability_id' => ability.id,
        'apply_error' => nil,
        'resolved_assignment_id' => assignment.id,
        'join_milestone' => (row['join_milestone'] || {}).stringify_keys.merge('level' => join_level)
      )
      rows[idx] = row
      merged_preview = @event.preview_actions.merge('rows' => rows)
      results = append_result_success(ability, assignment, join_level)
      @event.update!(preview_actions: merged_preview, results: results)

      BulkSyncEvent::UploadAbilitiesHrReview.mark_completed_if_done!(@event)

      Result.ok(ability: ability)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(', '))
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    def pick_text(desc_hash, override)
      h = desc_hash.is_a?(Hash) ? desc_hash.stringify_keys : {}
      o = override.to_s.presence
      return o if o

      h['proposed'].presence || h['normalized'].presence || h['raw'].presence
    end

    def pick_milestone_text(row, n, override)
      o = override.to_s.presence
      return o if o

      h = (row['milestones'] || {})[n.to_s]
      h = h.stringify_keys if h.is_a?(Hash)
      return '' unless h.is_a?(Hash)

      h['proposed'].presence || h['normalized'].presence || h['raw'].presence || ''
    end

    def append_result_success(ability, assignment, join_level)
      @event.reload
      results = @event.results.is_a?(Hash) ? @event.results.deep_stringify_keys : { 'successes' => [], 'failures' => [] }
      results['successes'] ||= []
      results['successes'] << {
        'type' => 'ability_import_row',
        'ability_id' => ability.id,
        'assignment_id' => assignment.id,
        'ability_name' => ability.name,
        'assignment_title' => assignment.title,
        'milestone_level' => join_level
      }
      results
    end
  end
end
