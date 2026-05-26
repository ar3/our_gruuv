# frozen_string_literal: true

module AbilitiesHrReview
  # Persists one ability group (create new or update existing); does not touch AssignmentAbility.
  class ApproveAbilityGroup
    def self.call(bulk_sync_event:, ability_group_id:, person:, mode:, overrides: {})
      new(
        bulk_sync_event: bulk_sync_event,
        ability_group_id: ability_group_id,
        person: person,
        mode: mode,
        overrides: overrides
      ).call
    end

    def initialize(bulk_sync_event:, ability_group_id:, person:, mode:, overrides: {})
      @event = bulk_sync_event
      @ability_group_id = ability_group_id.to_s
      @person = person
      @mode = mode.to_s
      @overrides = overrides.stringify_keys
    end

    def call
      unless @event.is_a?(BulkSyncEvent::UploadAbilitiesHrReview)
        return Result.err('Invalid bulk sync event type')
      end

      preview = @event.preview_actions.deep_stringify_keys
      groups = Array(preview['ability_groups'])
      idx = groups.index { |g| g['id'].to_s == @ability_group_id }
      return Result.err('Ability group not found') unless idx

      group = groups[idx]
      return Result.err('Ability group is invalid') if group['state'] == 'invalid'
      return Result.err('Ability group already applied') if group['state'] == 'applied'
      return Result.err('Ability group was skipped') if group['state'] == 'skipped'

      name = (@overrides['ability_name'].presence || group['form_ability_name'].presence || group['ability_name']).to_s.strip
      return Result.err('Ability name is required') if name.blank?

      description = TextPicker.pick_text(group['description'], @overrides['description'])
      return Result.err('Description is required') if description.blank?

      milestone_attrs = {}
      (1..5).each do |n|
        milestone_attrs["milestone_#{n}_description"] = TextPicker.pick_milestone_text(
          group['milestones'],
          n,
          @overrides["milestone_#{n}_description"]
        )
      end

      department_id = resolve_department_id(@overrides['department_id'])

      ability = nil
      ability_action = nil

      ApplicationRecord.transaction do
        case @mode
        when 'create'
          ability = Ability.new(
            company_id: @event.organization_id,
            name: name,
            description: description,
            created_by: @person,
            updated_by: @person,
            department_id: department_id
          )
          milestone_attrs.each { |attr, val| ability[attr] = val }
          ability.save!
          ability_action = 'created'
        when 'update'
          matched_id = group['matched_ability_id']
          return Result.err('No matched ability to update') if matched_id.blank?

          ability = Ability.find_by(id: matched_id, company_id: @event.organization_id)
          return Result.err('Matched ability not found') unless ability

          ability.assign_attributes(
            name: name,
            description: description,
            updated_by: @person,
            department_id: department_id
          )
          milestone_attrs.each { |attr, val| ability[attr] = val }
          ability.save!
          ability_action = 'updated'
        else
          return Result.err('Invalid approval mode')
        end
      end

      group = group.merge(
        'state' => 'applied',
        'applied_ability_id' => ability.id,
        'ability_action' => ability_action,
        'form_ability_name' => name,
        'existing_associations' => ExistingAssociations.list(
          organization: @event.organization,
          ability_id: ability.id
        ),
        'apply_error' => nil
      )
      groups[idx] = group
      @event.update!(preview_actions: preview.merge('ability_groups' => groups))

      Result.ok(ability: ability)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(', '))
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    def resolve_department_id(override)
      id = override.presence&.to_i
      return nil unless id&.positive?

      id
    end
  end
end
