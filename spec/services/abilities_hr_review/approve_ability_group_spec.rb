# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReview::ApproveAbilityGroup do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }

  let(:event) do
    create(
      :upload_abilities_hr_review,
      organization: organization,
      creator: person,
      initiator: person,
      source_contents: 'x',
      preview_actions: {
        'parse_ok' => true,
        'version' => 2,
        'ability_groups' => [
          {
            'id' => 'g1',
            'state' => 'pending',
            'ability_name' => 'Knife work',
            'form_ability_name' => 'Knife work',
            'matched_ability_id' => nil,
            'description' => { 'raw' => 'Body', 'normalized' => 'Body', 'proposed' => nil },
            'milestones' => {
              '1' => { 'raw' => 'M1', 'normalized' => 'M1', 'proposed' => nil },
              '2' => { 'raw' => '', 'normalized' => '', 'proposed' => nil },
              '3' => { 'raw' => '', 'normalized' => '', 'proposed' => nil },
              '4' => { 'raw' => '', 'normalized' => '', 'proposed' => nil },
              '5' => { 'raw' => '', 'normalized' => '', 'proposed' => nil }
            }
          }
        ],
        'association_rows' => []
      }
    )
  end

  it 'creates a new ability without assignment links' do
    result = described_class.call(
      bulk_sync_event: event,
      ability_group_id: 'g1',
      person: person,
      mode: 'create',
      overrides: {}
    )
    expect(result.ok?).to be true

    ability = Ability.find_by(company_id: organization.id, name: 'Knife work')
    expect(ability).to be_present
    expect(AssignmentAbility.where(ability_id: ability.id)).to be_empty

    group = event.reload.preview_actions['ability_groups'].first
    expect(group['state']).to eq('applied')
    expect(group['applied_ability_id']).to eq(ability.id)
    expect(group['existing_associations']).to eq([])
  end

  context 'when a different ability was matched at preview time' do
    let!(:matched) do
      create(:ability, company: organization, name: 'Other', created_by: person, updated_by: person)
    end
    let!(:other_assignment) { create(:assignment, company: organization, title: 'Prep') }

    before do
      AssignmentAbility.create!(assignment: other_assignment, ability: matched, milestone_level: 3)
      event.preview_actions['ability_groups'].first.merge!(
        'matched_ability_id' => matched.id,
        'existing_associations' => [
          {
            'assignment_id' => other_assignment.id,
            'assignment_title' => 'Prep',
            'milestone_level' => 3
          }
        ]
      )
      event.save!
    end

    it 'refreshes existing_associations from the created ability, not the match' do
      described_class.call(
        bulk_sync_event: event,
        ability_group_id: 'g1',
        person: person,
        mode: 'create',
        overrides: {}
      )

      group = event.reload.preview_actions['ability_groups'].first
      expect(group['applied_ability_id']).not_to eq(matched.id)
      expect(group['existing_associations']).to eq([])
    end
  end
end
