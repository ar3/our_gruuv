require 'rails_helper'

RSpec.describe 'Highlight Points Mode', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/company_teammates/:id/highlights_points' do
    it 'returns success' do
      get highlights_points_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
    end

    it 'renders the highlights_points template' do
      get highlights_points_organization_company_teammate_path(organization, teammate)
      expect(response).to render_template(:highlights_points)
    end

    it 'shows points to give and points to redeem (balance)' do
      get highlights_points_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('Points to Give')
      expect(response.body).to include('Points to Redeem')
    end

    it 'shows Transaction History section' do
      get highlights_points_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('Transaction History')
    end

    it 'shows Highlight Points Mode in view switcher when on page' do
      get highlights_points_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('Highlight Points Mode')
    end

    it 'shows Highlight Points Mode as an enabled link when viewing own About Me page' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      highlights_path = highlights_points_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include(highlights_path), "View switcher should show enabled Highlight Points link for viewing teammate on own page"
    end
  end

  describe 'authorization (self or managerial hierarchy only)' do
    let(:other_person) { create(:person) }
    let(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }

    before do
      create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      other_teammate.update!(first_employed_at: 1.year.ago)
      # Sign in as other_person (a peer, not in person's managerial hierarchy)
      sign_in_as_teammate_for_request(other_person, organization)
    end

    it 'denies access when viewing another teammate not in hierarchy' do
      get highlights_points_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end

    it 'allows access when viewing own page' do
      get highlights_points_organization_company_teammate_path(organization, other_teammate)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'view switcher shows enabled Highlight Points link for manager viewing report' do
    let(:manager_person) { create(:person) }
    let(:manager_teammate) { create(:company_teammate, person: manager_person, organization: organization) }
    let(:report_person) { create(:person) }
    let(:report_teammate) { create(:company_teammate, person: report_person, organization: organization) }

    before do
      create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 2.years.ago, ended_at: nil)
      create(:employment_tenure, teammate: report_teammate, company: organization, started_at: 1.year.ago, ended_at: nil, manager_teammate: manager_teammate)
      manager_teammate.update!(first_employed_at: 2.years.ago)
      report_teammate.update!(first_employed_at: 1.year.ago)
      sign_in_as_teammate_for_request(manager_person, organization)
    end

    it 'allows manager to access report’s highlights_points page' do
      get highlights_points_organization_company_teammate_path(organization, report_teammate)
      expect(response).to have_http_status(:success)
    end

    it 'shows Highlight Points Mode as an enabled link when manager views report’s About Me page' do
      get about_me_organization_company_teammate_path(organization, report_teammate)
      expect(response).to have_http_status(:success)
      highlights_path = highlights_points_organization_company_teammate_path(organization, report_teammate)
      expect(response.body).to include(highlights_path), "View switcher should show enabled Highlight Points link for manager viewing report's page"
    end
  end
end
