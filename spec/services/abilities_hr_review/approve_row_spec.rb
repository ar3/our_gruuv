# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReview::ApproveRow do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:assignment) { create(:assignment, company: organization, title: 'Line Cook', tagline: 'Cook things') }
  let(:event) do
    create(
      :upload_abilities_hr_review,
      organization: organization,
      creator: person,
      initiator: person,
      source_contents: 'x',
      preview_actions: {
        'parse_ok' => true,
        'rows' => [
          {
            'id' => 'row1',
            'state' => 'pending',
            'resolved_assignment_id' => assignment.id,
            'ability_name' => 'Knife work',
            'description' => { 'raw' => 'Body', 'normalized' => 'Body', 'proposed' => nil },
            'milestones' => {
              '1' => { 'raw' => 'M1', 'normalized' => 'M1', 'proposed' => nil },
              '2' => { 'raw' => '', 'normalized' => '', 'proposed' => nil },
              '3' => { 'raw' => '', 'normalized' => '', 'proposed' => nil },
              '4' => { 'raw' => '', 'normalized' => '', 'proposed' => nil },
              '5' => { 'raw' => '', 'normalized' => '', 'proposed' => nil }
            },
            'join_milestone' => { 'level' => 2, 'proposed_level' => nil, 'rationale' => nil }
          }
        ]
      }
    )
  end

  it 'creates ability and assignment_ability' do
    result = described_class.call(bulk_sync_event: event, row_id: 'row1', person: person, overrides: {})
    expect(result.ok?).to be true

    ability = Ability.find_by(company_id: organization.id, name: 'Knife work')
    expect(ability).to be_present
    expect(ability.description).to eq('Body')
    expect(ability.milestone_1_description).to eq('M1')

    aa = AssignmentAbility.find_by(assignment_id: assignment.id, ability_id: ability.id)
    expect(aa).to be_present
    expect(aa.milestone_level).to eq(2)

    event.reload
    row = event.preview_actions['rows'].first
    expect(row['state']).to eq('applied')
    expect(row['applied_ability_id']).to eq(ability.id)
  end
end
