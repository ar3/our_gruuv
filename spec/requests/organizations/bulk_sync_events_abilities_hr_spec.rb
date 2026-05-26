# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Bulk sync HR abilities import', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:maap_teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }
  let!(:assignment) { create(:assignment, company: organization, title: 'Line Cook') }

  let(:csv) do
    <<~CSV
      Assignment,Ability,Description,Milestone 1,Milestone 2,Milestone 3,Milestone 4,Milestone 5,Ability milestone
      Line Cook,,
      ,Knife work,Use knives safely.,M1,,,,,2
    CSV
  end

  before do
    PaperTrail.enabled = false
    sign_in_as_teammate_for_request(person, organization)
    allow(AbilitiesHrReview::EnrichPreview).to receive(:call).and_return(true)
  end

  after { PaperTrail.enabled = true }

  it 'creates bulk sync event and shows review page' do
    post organization_bulk_sync_events_path(organization), params: {
      bulk_sync_event: {
        type: 'BulkSyncEvent::UploadAbilitiesHrReview',
        file: fixture_file_upload('hr_abilities.csv', 'text/csv')
      }
    }

    expect(response).to redirect_to(%r{/bulk_sync_events/\d+\z})
    event = BulkSyncEvent::UploadAbilitiesHrReview.order(:id).last
    expect(event.preview_actions['parse_ok']).to be true
    expect(event.preview_actions['ability_groups'].size).to eq(1)

    get organization_bulk_sync_event_path(organization, event)
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Knife work')
    expect(response.body).to include('Step 1')
  end

  it 'approves ability then association' do
    preview = AbilitiesHrReview::BuildPreview.call(file_content: csv, organization: organization)[:preview_actions]
    event = create(
      :upload_abilities_hr_review,
      organization: organization,
      creator: person,
      initiator: person,
      source_contents: csv,
      preview_actions: preview.merge('parse_ok' => true)
    )

    group_id = event.preview_actions['ability_groups'].first['id']

    post approve_abilities_hr_ability_group_organization_bulk_sync_event_path(organization, event), params: {
      ability_group_id: group_id,
      mode: 'create',
      ability_name: 'Knife work',
      description: 'Use knives safely.',
      milestone_1_description: 'M1',
      milestone_2_description: '',
      milestone_3_description: '',
      milestone_4_description: '',
      milestone_5_description: ''
    }

    expect(response).to redirect_to(
      organization_bulk_sync_event_path(organization, event, anchor: "ability-group-#{group_id}")
    )
    expect(Ability.exists?(company_id: organization.id, name: 'Knife work')).to be true

    assoc_id = event.reload.preview_actions['association_rows'].first['id']
    post process_abilities_hr_associations_organization_bulk_sync_event_path(organization, event), params: {
      association_submissions: [
        {
          association_row_id: assoc_id,
          action: 'apply',
          resolved_assignment_id: assignment.id,
          join_milestone_level: 2
        }
      ]
    }

    expect(response).to redirect_to(
      organization_bulk_sync_event_path(organization, event, anchor: 'step-2-associations')
    )
    expect(event.reload.status).to eq('completed')
    ability = Ability.find_by(company_id: organization.id, name: 'Knife work')
    expect(AssignmentAbility.exists?(assignment_id: assignment.id, ability_id: ability.id)).to be true
  end
end
