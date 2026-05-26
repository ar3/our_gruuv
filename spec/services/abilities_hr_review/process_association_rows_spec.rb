# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReview::ProcessAssociationRows do
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
      preview_actions: {
        'ability_groups' => [
          {
            'id' => 'g1',
            'state' => 'applied',
            'applied_ability_id' => ability.id,
            'ability_action' => 'created'
          }
        ],
        'association_rows' => [
          {
            'id' => 'a1',
            'state' => 'pending',
            'ability_group_id' => 'g1',
            'resolved_assignment_id' => assignment.id,
            'join_milestone' => { 'level' => 2 }
          },
          {
            'id' => 'a2',
            'state' => 'pending',
            'ability_group_id' => 'g1',
            'resolved_assignment_id' => assignment.id,
            'join_milestone' => { 'level' => 1 }
          }
        ]
      }
    )
  end

  it 'applies and skips rows in one submission' do
    result = described_class.call(
      bulk_sync_event: event,
      person: person,
      submissions: [
        {
          'association_row_id' => 'a1',
          'action' => 'apply',
          'resolved_assignment_id' => assignment.id,
          'join_milestone_level' => '2'
        },
        { 'association_row_id' => 'a2', 'action' => 'skip' }
      ]
    )

    expect(result.ok?).to be true
    rows = event.reload.preview_actions['association_rows']
    expect(rows.find { |r| r['id'] == 'a1' }['state']).to eq('applied')
    expect(rows.find { |r| r['id'] == 'a2' }['state']).to eq('skipped')
  end
end
