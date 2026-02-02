require 'rails_helper'

RSpec.describe Organizations::PublicMaap::AbilitiesController, type: :controller do
  let(:company) { create(:organization) }
  let(:department) { create(:department, company: company) }
  let(:created_by) { create(:person) }
  let(:updated_by) { create(:person) }
  
  let!(:ability_company) do
    create(:ability, company: company, name: 'Company Ability', created_by: created_by, updated_by: updated_by)
  end

  let!(:ability_department) do
    create(:ability, company: company, department: department, name: 'Department Ability', created_by: created_by, updated_by: updated_by)
  end

  let(:observer) { create(:person) }
  let(:observation) do
    obs = create(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: Time.current)
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

    it 'groups abilities by department' do
      get :index, params: { organization_id: company.id }
      abilities_by_org = assigns(:abilities_by_org)
      
      # Abilities are grouped by department (nil key = company-level abilities)
      expect(abilities_by_org[nil]).to include(ability_company)
      expect(abilities_by_org[department]).to include(ability_department)
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
      draft_obs = create(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: nil)
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

