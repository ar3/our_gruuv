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
      expect(response.body).to include('Consult OG about')
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

    it 'stores consult_focus when provided' do
      post run_maap_clarity_organization_assignment_path(organization, assignment),
           params: { consult_focus: '  Are outcomes clear enough?  ' }

      run = MaapAgentRun.find_by(subject: assignment, agent_kind: MaapAgentRun::AGENT_KIND_ASSIGNMENT_CLARITY)
      expect(run.consult_focus).to eq('Are outcomes clear enough?')
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

  describe 'POST .../maap_clarity/recommendations/accept' do
    let!(:run) do
      MaapAgentRun.create!(
        subject: assignment,
        agent_kind: MaapAgentRun::AGENT_KIND_ASSIGNMENT_CLARITY,
        status: 'completed',
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
        output_text: 'ok',
        clarity_recommendations: [
          {
            'id' => 'rec_test',
            'confidence' => 'high',
            'kind' => 'edit_tagline',
            'title' => 'Fix tagline',
            'rationale' => 'Clearer scope.',
            'payload' => {}
          }
        ]
      )
    end

    it 'records a quick accept for a valid recommendation id' do
      expect do
        post accept_maap_clarity_recommendation_organization_assignment_path(organization, assignment),
             params: { recommendation_id: 'rec_test' }
      end.to change(MaapRecommendationAcceptance, :count).by(1)

      expect(response).to redirect_to(maap_clarity_organization_assignment_path(organization, assignment))
      acc = MaapRecommendationAcceptance.last
      expect(acc.maap_agent_run_id).to eq(run.id)
      expect(acc.recommendation_id).to eq('rec_test')
      expect(acc.teammate_id).to eq(maap_teammate.id)
    end

    it 'rejects unknown recommendation ids' do
      post accept_maap_clarity_recommendation_organization_assignment_path(organization, assignment),
           params: { recommendation_id: 'nope' }

      expect(response).to redirect_to(maap_clarity_organization_assignment_path(organization, assignment))
      expect(flash[:alert]).to be_present
      expect(MaapRecommendationAcceptance.count).to eq(0)
    end

    it 'is idempotent when accepting twice' do
      post accept_maap_clarity_recommendation_organization_assignment_path(organization, assignment),
           params: { recommendation_id: 'rec_test' }
      expect do
        post accept_maap_clarity_recommendation_organization_assignment_path(organization, assignment),
             params: { recommendation_id: 'rec_test' }
      end.not_to change(MaapRecommendationAcceptance, :count)
    end
  end
end
