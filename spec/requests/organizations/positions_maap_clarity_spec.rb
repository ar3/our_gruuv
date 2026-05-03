# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::Positions::MaapClarity', type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company, name: 'Spec Org') }
  let(:person) { create(:person) }
  let!(:maap_teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let!(:position) { create(:position, title: title, position_level: position_level) }

  before do
    sign_in_as_teammate_for_request(person, organization)
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/positions/:id/maap_clarity' do
    it 'loads the clarity page for MAAP users' do
      get maap_clarity_organization_position_path(organization, position)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Consult OG about')
    end
  end

  describe 'POST /organizations/:organization_id/positions/:id/maap_clarity/run' do
    it 'creates a run and enqueues the job' do
      expect do
        post run_maap_clarity_organization_position_path(organization, position)
      end.to have_enqueued_job(PositionClarityJob).with(position.id, a_kind_of(Integer))

      expect(response).to redirect_to(maap_clarity_organization_position_path(organization, position))
      run = MaapAgentRun.find_by(subject: position, agent_kind: MaapAgentRun::AGENT_KIND_POSITION_CLARITY)
      expect(run).to be_present
      expect(run.status).to eq('pending')
    end
  end

  describe 'GET /organizations/:organization_id/positions/:id/maap_clarity/status' do
    let!(:position_for_status) do
      t = create(:title, company: organization, external_title: 'Other Title')
      pl = create(:position_level, position_major_level: t.position_major_level)
      create(:position, title: t, position_level: pl)
    end

    it 'returns JSON for the current run' do
      MaapAgentRun.create!(
        subject: position_for_status,
        agent_kind: MaapAgentRun::AGENT_KIND_POSITION_CLARITY,
        status: 'processing',
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
      )

      get maap_clarity_status_organization_position_path(organization, position_for_status),
          headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('processing')
    end
  end
end
