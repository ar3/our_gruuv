# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::Assignments::MaapClarity', type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company, name: 'Spec Org') }
  let(:person) { create(:person) }
  let!(:maap_teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }
  let!(:assignment) { create(:assignment, company: organization) }

  before do
    sign_in_as_teammate_for_request(person, organization)
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/assignments/:id/maap_clarity' do
    it 'loads the clarity page for MAAP users' do
      get maap_clarity_organization_assignment_path(organization, assignment)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('MAAP clarity review')
    end
  end

  describe 'POST /organizations/:organization_id/assignments/:id/maap_clarity/run' do
    it 'creates a run and enqueues the job' do
      expect do
        post run_maap_clarity_organization_assignment_path(organization, assignment)
      end.to have_enqueued_job(AssignmentClarityJob).with(assignment.id, a_kind_of(Integer))

      expect(response).to redirect_to(maap_clarity_organization_assignment_path(organization, assignment))
      run = MaapAgentRun.find_by(subject: assignment, agent_kind: MaapAgentRun::AGENT_KIND_ASSIGNMENT_CLARITY)
      expect(run).to be_present
      expect(run.status).to eq('pending')
    end
  end

  describe 'GET /organizations/:organization_id/assignments/:id/maap_clarity/status' do
    let!(:assignment_for_status) { create(:assignment, company: organization, title: 'Other Assignment') }

    it 'returns JSON for the current run' do
      MaapAgentRun.create!(
        subject: assignment_for_status,
        agent_kind: MaapAgentRun::AGENT_KIND_ASSIGNMENT_CLARITY,
        status: 'processing',
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
      )

      get maap_clarity_status_organization_assignment_path(organization, assignment_for_status),
          headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('processing')
    end
  end
end
