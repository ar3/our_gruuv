require 'rails_helper'

RSpec.describe 'Kudos Points Mode', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/company_teammates/:id/kudos_points' do
    it 'returns success' do
      get kudos_points_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
    end

    it 'renders the kudos_points template' do
      get kudos_points_organization_company_teammate_path(organization, teammate)
      expect(response).to render_template(:kudos_points)
    end

    it 'shows kudos point labels for balance (to give and to redeem)' do
      get kudos_points_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('Kudos Points to Give')
      expect(response.body).to include('Kudos Points to Redeem')
    end

    it 'shows Transaction History section' do
      get kudos_points_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('Transaction History')
    end

    it 'shows Kudos Points Mode in view switcher when on page' do
      get kudos_points_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('Kudos Points Mode')
    end

    it 'shows Kudos Points Mode as an enabled link when viewing own About Me page' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      kudos_path = kudos_points_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include(kudos_path), "View switcher should show enabled Kudos Points link for viewing teammate on own page"
    end

    it 'does not show a back link when return_url and return_text are not in query params' do
      get kudos_points_organization_company_teammate_path(organization, teammate)
      expect(response.body).not_to include('go-back-link')
      expect(response.body).not_to include('Back to About Me')
    end

    it 'shows back link with given url and text when return_url and return_text are in query params' do
      about_path = about_me_organization_company_teammate_path(organization, teammate)
      get kudos_points_organization_company_teammate_path(organization, teammate), params: { return_url: about_path, return_text: 'Back to About Me' }
      expect(response.body).to include('go-back-link')
      expect(response.body).to include('Back to About Me')
      expect(response.body).to include(about_path)
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
      get kudos_points_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end

    it 'allows access when viewing own page' do
      get kudos_points_organization_company_teammate_path(organization, other_teammate)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'view switcher shows enabled Kudos Points link for manager viewing report' do
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

    it 'allows manager to access report’s kudos_points page' do
      get kudos_points_organization_company_teammate_path(organization, report_teammate)
      expect(response).to have_http_status(:success)
    end

    it 'shows Kudos Points Mode as an enabled link when manager views report’s About Me page' do
      get about_me_organization_company_teammate_path(organization, report_teammate)
      expect(response).to have_http_status(:success)
      kudos_path = kudos_points_organization_company_teammate_path(organization, report_teammate)
      expect(response.body).to include(kudos_path), "View switcher should show enabled Kudos Points link for manager viewing report's page"
    end
  end

  describe 'manage_employment permission' do
    let(:employment_manager_person) { create(:person) }
    let(:employment_manager_teammate) { create(:company_teammate, person: employment_manager_person, organization: organization, can_manage_employment: true) }
    let(:peer_person) { create(:person) }
    let(:peer_teammate) { create(:company_teammate, person: peer_person, organization: organization) }

    before do
      create(:employment_tenure, teammate: employment_manager_teammate, company: organization, started_at: 2.years.ago, ended_at: nil)
      create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      employment_manager_teammate.update!(first_employed_at: 2.years.ago)
      peer_teammate.update!(first_employed_at: 1.year.ago)
      sign_in_as_teammate_for_request(employment_manager_person, organization)
    end

    it 'allows user with manage_employment to view any teammate’s kudos_points page' do
      get kudos_points_organization_company_teammate_path(organization, peer_teammate)
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:kudos_points)
    end

    it 'shows Kudos Points Mode as an enabled link when manage_employment user views peer’s About Me page' do
      get about_me_organization_company_teammate_path(organization, peer_teammate)
      expect(response).to have_http_status(:success)
      kudos_path = kudos_points_organization_company_teammate_path(organization, peer_teammate)
      expect(response.body).to include(kudos_path), "View switcher should show enabled Kudos Points link for manage_employment viewing peer's page"
    end
  end

  describe 'can_manage_kudos_rewards permission' do
    let(:kudos_manager_person) { create(:person) }
    let(:kudos_manager_teammate) { create(:company_teammate, person: kudos_manager_person, organization: organization, can_manage_kudos_rewards: true) }
    let(:peer_person) { create(:person) }
    let(:peer_teammate) { create(:company_teammate, person: peer_person, organization: organization) }

    before do
      create(:employment_tenure, teammate: kudos_manager_teammate, company: organization, started_at: 2.years.ago, ended_at: nil)
      create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      kudos_manager_teammate.update!(first_employed_at: 2.years.ago)
      peer_teammate.update!(first_employed_at: 1.year.ago)
      sign_in_as_teammate_for_request(kudos_manager_person, organization)
    end

    it 'allows user with can_manage_kudos_rewards to view any teammate\'s kudos_points page' do
      get kudos_points_organization_company_teammate_path(organization, peer_teammate)
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:kudos_points)
    end

    it 'shows Kudos Points Mode in view switcher when can_manage_kudos_rewards user views peer\'s kudos_points page' do
      get kudos_points_organization_company_teammate_path(organization, peer_teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Kudos Points Mode')
      expect(response.body).to include('Transaction History')
    end
  end
end
