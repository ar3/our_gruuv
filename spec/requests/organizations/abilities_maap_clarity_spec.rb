# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::Abilities::MaapClarity', type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company, name: 'Spec Org') }
  let(:creator) { create(:person) }
  let(:person) { create(:person) }
  let!(:maap_teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }
  let!(:ability) { create(:ability, company: organization, created_by: creator, updated_by: creator) }

  before do
    sign_in_as_teammate_for_request(person, organization)
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/abilities/:id/maap_clarity' do
    it 'loads the clarity page for MAAP users' do
      get maap_clarity_organization_ability_path(organization, ability)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Consult OG about')
      expect(response.body).to include(ability.name)
    end
  end

  describe 'POST /organizations/:organization_id/abilities/:id/maap_clarity/run' do
    it 'creates a consultation and enqueues the job' do
      expect do
        post run_maap_clarity_organization_ability_path(organization, ability)
      end.to have_enqueued_job(AbilityClarityJob).with(ability.id, a_kind_of(Integer))

      expect(response).to redirect_to(maap_clarity_organization_ability_path(organization, ability))
      run = ability.latest_ability_clarity_consultation
      expect(run).to be_present
      expect(run.status).to eq('pending')
      expect(run).to be_a(OgConsultation)
    end
  end

  describe 'GET /organizations/:organization_id/abilities/:id/maap_clarity/status' do
    let!(:ability_for_status) { create(:ability, company: organization, created_by: creator, updated_by: creator, name: 'Other Ability') }

    it 'returns JSON for the current consultation' do
      create_ability_clarity_consultation!(ability: ability_for_status, status: 'processing')

      get maap_clarity_status_organization_ability_path(organization, ability_for_status),
          headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('processing')
    end
  end
end
