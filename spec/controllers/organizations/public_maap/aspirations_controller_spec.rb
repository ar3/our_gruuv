require 'rails_helper'

RSpec.describe Organizations::PublicMaap::AspirationsController, type: :controller do
  let(:company) { create(:organization) }
  let(:department) { create(:department, company: company) }
  
  let!(:aspiration_company) do
    create(:aspiration, company: company, name: 'Company Aspiration')
  end

  let!(:aspiration_department) do
    create(:aspiration, company: company, department: department, name: 'Department Aspiration')
  end

  let(:observer) { create(:person) }
  let(:observation) do
    obs = create(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: Time.current)
    create(:observation_rating, observation: obs, rateable: aspiration_company, rating: :strongly_agree)
    obs
  end

  describe 'GET #index' do
    it 'renders successfully without authentication' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'shows all aspirations (no public/private filter)' do
      get :index, params: { organization_id: company.id }
      aspirations = assigns(:aspirations)
      
      expect(aspirations).to include(aspiration_company)
      expect(aspirations).to include(aspiration_department)
    end

    it 'groups aspirations by department' do
      get :index, params: { organization_id: company.id }
      aspirations_by_org = assigns(:aspirations_by_org)
      
      # Aspirations are grouped by department (nil key = company-level aspirations)
      expect(aspirations_by_org[nil]).to include(aspiration_company)
      expect(aspirations_by_org[department]).to include(aspiration_department)
    end
  end

  describe 'GET #show' do
    before { observation }

    it 'renders successfully without authentication' do
      get :show, params: { organization_id: company.id, id: aspiration_company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the aspiration' do
      get :show, params: { organization_id: company.id, id: aspiration_company.id }
      expect(assigns(:aspiration)).to eq(aspiration_company)
    end

    it 'assigns public and published observations' do
      # Create a non-public observation
      private_obs = create(:observation, observer: observer, company: company, privacy_level: :observer_only, published_at: Time.current)
      create(:observation_rating, observation: private_obs, rateable: aspiration_company, rating: :agree)
      
      # Create an unpublished observation
      draft_obs = create(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: nil)
      create(:observation_rating, observation: draft_obs, rateable: aspiration_company, rating: :agree)
      
      get :show, params: { organization_id: company.id, id: aspiration_company.id }
      observations = assigns(:observations)
      
      expect(observations).to include(observation)
      expect(observations).not_to include(private_obs)
      expect(observations).not_to include(draft_obs)
    end

    it 'handles id-name-parameterized format' do
      param = aspiration_company.to_param
      get :show, params: { organization_id: company.id, id: param }
      expect(assigns(:aspiration)).to eq(aspiration_company)
    end
  end
end

