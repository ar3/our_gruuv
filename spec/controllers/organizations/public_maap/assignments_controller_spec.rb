require 'rails_helper'

RSpec.describe Organizations::PublicMaap::AssignmentsController, type: :controller do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: company) }
  let(:team) { create(:organization, :team, parent: department) }
  
  let!(:assignment_company) do
    create(:assignment, company: company, title: 'Company Assignment')
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

  describe 'GET #index' do
    it 'renders successfully without authentication' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'shows all assignments' do
      get :index, params: { organization_id: company.id }
      assignments = assigns(:assignments)
      
      expect(assignments).to include(assignment_company)
      expect(assignments).to include(assignment_department)
    end

    it 'groups assignments by organization' do
      get :index, params: { organization_id: company.id }
      assignments_by_org = assigns(:assignments_by_org)
      
      # Find the organization key in the hash (may be Company/Department instance due to STI)
      company_key = assignments_by_org.keys.find { |org| org.id == company.id }
      department_key = assignments_by_org.keys.find { |org| org.id == department.id }
      
      expect(assignments_by_org[company_key]).to include(assignment_company)
      expect(assignments_by_org[department_key]).to include(assignment_department)
    end

    it 'excludes teams from hierarchy' do
      team_assignment = create(:assignment, company: team, title: 'Team Assignment')
      
      get :index, params: { organization_id: company.id }
      assignments = assigns(:assignments)
      
      expect(assignments).not_to include(team_assignment)
    end
  end

  describe 'GET #show' do
    before { observation }

    it 'renders successfully without authentication' do
      get :show, params: { organization_id: company.id, id: assignment_company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the assignment' do
      get :show, params: { organization_id: company.id, id: assignment_company.id }
      expect(assigns(:assignment)).to eq(assignment_company)
    end

    it 'assigns public and published observations' do
      # Create a non-public observation
      private_obs = create(:observation, observer: observer, company: company, privacy_level: :observer_only, published_at: Time.current)
      create(:observation_rating, observation: private_obs, rateable: assignment_company, rating: :agree)
      
      # Create an unpublished observation
      draft_obs = create(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: nil)
      create(:observation_rating, observation: draft_obs, rateable: assignment_company, rating: :agree)
      
      get :show, params: { organization_id: company.id, id: assignment_company.id }
      observations = assigns(:observations)
      
      expect(observations).to include(observation)
      expect(observations).not_to include(private_obs)
      expect(observations).not_to include(draft_obs)
    end

    it 'handles id-name-parameterized format' do
      param = assignment_company.to_param
      get :show, params: { organization_id: company.id, id: param }
      expect(assigns(:assignment)).to eq(assignment_company)
    end
  end
end

