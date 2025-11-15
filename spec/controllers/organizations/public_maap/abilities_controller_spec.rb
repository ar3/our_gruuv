require 'rails_helper'

RSpec.describe Organizations::PublicMaap::AbilitiesController, type: :controller do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: company) }
  let(:created_by) { create(:person) }
  let(:updated_by) { create(:person) }
  
  let!(:ability_company) do
    create(:ability, organization: company, name: 'Company Ability', created_by: created_by, updated_by: updated_by)
  end

  let!(:ability_department) do
    create(:ability, organization: department, name: 'Department Ability', created_by: created_by, updated_by: updated_by)
  end

  let(:observer) { create(:person) }
  let(:observation) do
    obs = create(:observation, observer: observer, company: company, privacy_level: :public_observation, published_at: Time.current)
    create(:observation_rating, observation: obs, rateable: ability_company, rating: :strongly_agree)
    obs
  end

  describe 'GET #index' do
    it 'renders successfully without authentication' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'shows all abilities' do
      get :index, params: { organization_id: company.id }
      abilities = assigns(:abilities)
      
      expect(abilities).to include(ability_company)
      expect(abilities).to include(ability_department)
    end

    it 'groups abilities by organization' do
      get :index, params: { organization_id: company.id }
      abilities_by_org = assigns(:abilities_by_org)
      
      # Find the organization key in the hash (may be Company/Department instance due to STI)
      company_key = abilities_by_org.keys.find { |org| org.id == company.id }
      department_key = abilities_by_org.keys.find { |org| org.id == department.id }
      
      expect(abilities_by_org[company_key]).to include(ability_company)
      expect(abilities_by_org[department_key]).to include(ability_department)
    end
  end

  describe 'GET #show' do
    before { observation }

    it 'renders successfully without authentication' do
      get :show, params: { organization_id: company.id, id: ability_company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the ability' do
      get :show, params: { organization_id: company.id, id: ability_company.id }
      expect(assigns(:ability)).to eq(ability_company)
    end

    it 'assigns public and published observations' do
      # Create a non-public observation
      private_obs = create(:observation, observer: observer, company: company, privacy_level: :observer_only, published_at: Time.current)
      create(:observation_rating, observation: private_obs, rateable: ability_company, rating: :agree)
      
      # Create an unpublished observation
      draft_obs = create(:observation, observer: observer, company: company, privacy_level: :public_observation, published_at: nil)
      create(:observation_rating, observation: draft_obs, rateable: ability_company, rating: :agree)
      
      get :show, params: { organization_id: company.id, id: ability_company.id }
      observations = assigns(:observations)
      
      expect(observations).to include(observation)
      expect(observations).not_to include(private_obs)
      expect(observations).not_to include(draft_obs)
    end

    it 'handles id-name-parameterized format' do
      param = ability_company.to_param
      get :show, params: { organization_id: company.id, id: param }
      expect(assigns(:ability)).to eq(ability_company)
    end
  end
end

