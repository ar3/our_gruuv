require 'rails_helper'

RSpec.describe 'Organizations::PublicMaap::Assignments', type: :request do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: company) }
  let(:team) { create(:organization, :team, parent: department) }
  
  let!(:assignment_company) do
    create(:assignment, company: company, title: 'Company Assignment', tagline: 'A great assignment')
  end

  let!(:assignment_department) do
    create(:assignment, company: department, title: 'Department Assignment')
  end

  let(:observer) { create(:person) }
  let(:observation) do
    obs = create(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: Time.current)
    create(:observation_rating, observation: obs, rateable: assignment_company, rating: :strongly_agree)
    obs
  end

  describe 'GET /organizations/:organization_id/public_maap/assignments' do
    it 'renders successfully without authentication' do
      get organization_public_maap_assignments_path(company)
      expect(response).to have_http_status(:success)
    end

    it 'shows all assignments' do
      get organization_public_maap_assignments_path(company)
      expect(response.body).to include('Company Assignment')
      expect(response.body).to include('Department Assignment')
    end

    it 'groups assignments by organization' do
      get organization_public_maap_assignments_path(company)
      expect(response.body).to include(company.name)
      expect(response.body).to include(department.name)
    end

    it 'excludes teams from hierarchy' do
      team_assignment = create(:assignment, company: team, title: 'Team Assignment')
      
      get organization_public_maap_assignments_path(company)
      expect(response.body).not_to include('Team Assignment')
    end

    it 'shows link to authenticated version when user is logged in' do
      person = create(:person)
      sign_in_as_teammate_for_request(person, company)
      
      get organization_public_maap_assignments_path(company)
      expect(response.body).to include('View Authenticated Version')
    end

    it 'does not show link to authenticated version when user is not logged in' do
      get organization_public_maap_assignments_path(company)
      expect(response.body).not_to include('View Authenticated Version')
    end
  end

  describe 'GET /organizations/:organization_id/public_maap/assignments/:id' do
    before { observation }

    it 'renders successfully without authentication' do
      get organization_public_maap_assignment_path(company, assignment_company)
      expect(response).to have_http_status(:success)
    end

    it 'displays assignment title' do
      get organization_public_maap_assignment_path(company, assignment_company)
      expect(response.body).to include('Company Assignment')
    end

    it 'displays assignment tagline' do
      get organization_public_maap_assignment_path(company, assignment_company)
      expect(response.body).to include('A great assignment')
    end

    it 'displays public and published observations' do
      # Create a non-public observation
      private_obs = create(:observation, observer: observer, company: company, privacy_level: :observer_only, published_at: Time.current)
      create(:observation_rating, observation: private_obs, rateable: assignment_company, rating: :agree)
      
      # Create an unpublished observation
      draft_obs = create(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: nil)
      create(:observation_rating, observation: draft_obs, rateable: assignment_company, rating: :agree)
      
      get organization_public_maap_assignment_path(company, assignment_company)
      
      expect(response.body).to include('Public Observations')
      expect(response.body).to include(observation.decorate.story_html)
      expect(response.body).not_to include(private_obs.decorate.story_html)
      expect(response.body).not_to include(draft_obs.decorate.story_html)
    end

    it 'handles id-name-parameterized format' do
      param = assignment_company.to_param
      get organization_public_maap_assignment_path(company, param)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Company Assignment')
    end

    it 'shows "View Authenticated Version" button when user is logged in' do
      person = create(:person)
      sign_in_as_teammate_for_request(person, company)
      
      get organization_public_maap_assignment_path(company, assignment_company)
      expect(response.body).to include('View Authenticated Version')
    end

    it 'does not show "View Authenticated Version" button when user is not logged in' do
      get organization_public_maap_assignment_path(company, assignment_company)
      expect(response.body).not_to include('View Authenticated Version')
    end

    context 'when assignment has outcomes' do
      let!(:outcome) do
        create(:assignment_outcome, assignment: assignment_company, description: 'Test outcome', outcome_type: 'sentiment')
      end

      it 'displays assignment outcomes' do
        get organization_public_maap_assignment_path(company, assignment_company)
        expect(response.body).to include('Test outcome')
        expect(response.body).to include('Sentiment')
      end
    end

    context 'when assignment has handbook' do
      before do
        assignment_company.update(handbook: '# Handbook Content')
      end

      it 'displays assignment handbook' do
        get organization_public_maap_assignment_path(company, assignment_company)
        expect(response.body).to include('Handbook')
        expect(response.body).to include('Handbook Content')
      end
    end
  end
end

