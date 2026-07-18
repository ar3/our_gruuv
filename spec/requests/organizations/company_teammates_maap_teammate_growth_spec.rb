# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::CompanyTeammates::MaapTeammateGrowth', type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company, name: 'Spec Org') }
  let(:viewer_person) { create(:person) }
  let!(:viewer_teammate) do
    create(:company_teammate, :employment_manager, person: viewer_person, organization: organization)
  end
  let(:subject_person) { create(:person) }
  let!(:subject_teammate) do
    create(:company_teammate, :assigned_employee, person: subject_person, organization: organization)
  end

  before do
    sign_in_as_teammate_for_request(viewer_person, organization)
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/company_teammates/:id/maap_teammate_growth' do
    it 'loads the teammate growth page for authorized users' do
      get maap_teammate_growth_organization_company_teammate_path(organization, subject_teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Consult OG about')
      expect(response.body).to include(subject_teammate.person.display_name)
    end
  end

  describe 'POST /organizations/:organization_id/company_teammates/:id/maap_teammate_growth/run' do
    it 'creates a consultation and enqueues the job' do
      expect do
        post run_maap_teammate_growth_organization_company_teammate_path(organization, subject_teammate)
      end.to have_enqueued_job(TeammateGrowthJob).with(subject_teammate.id, organization.id, a_kind_of(Integer))

      expect(response).to redirect_to(maap_teammate_growth_organization_company_teammate_path(organization, subject_teammate))
      run = subject_teammate.latest_teammate_growth_consultation
      expect(run).to be_present
      expect(run.status).to eq('pending')
    end
  end

  describe 'GET /organizations/:organization_id/company_teammates/:id/maap_teammate_growth/status' do
    it 'returns JSON for the current consultation' do
      create_teammate_growth_consultation!(
        teammate: subject_teammate,
        organization: organization,
        status: 'processing'
      )

      get maap_teammate_growth_status_organization_company_teammate_path(organization, subject_teammate),
          headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('processing')
    end
  end
end
