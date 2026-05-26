# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReview::ApproveAssociationRow do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:assignment) { create(:assignment, company: organization, title: 'Line Cook') }
  let!(:ability) { create(:ability, company: organization, name: 'Knife work', created_by: person, updated_by: person) }

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
            'state' => 'applied',
            'applied_ability_id' => ability.id,
            'ability_action' => 'created',
            'ability_name' => 'Knife work'
          }
        ],
        'association_rows' => [
          {
            'id' => 'a1',
            'state' => 'pending',
            'ability_group_id' => 'g1',
            'resolved_assignment_id' => assignment.id,
            'join_milestone' => { 'level' => 2 }
          }
        ]
      }
    )
  end

  it 'creates assignment_ability with milestone' do
    result = described_class.call(
      bulk_sync_event: event,
      association_row_id: 'a1',
      person: person,
      overrides: {}
    )
    expect(result.ok?).to be true

    aa = AssignmentAbility.find_by(assignment_id: assignment.id, ability_id: ability.id)
    expect(aa.milestone_level).to eq(2)
    expect(event.reload.status).to eq('completed')
  end
end
