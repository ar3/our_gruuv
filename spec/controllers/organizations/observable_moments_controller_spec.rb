require 'rails_helper'

RSpec.describe Organizations::ObservableMomentsController, type: :controller do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, organization: company, person: person) }
  let(:other_person) { create(:person) }
  let(:other_teammate) { create(:teammate, organization: company, person: other_person) }
  let(:observable_moment) do
    create(:observable_moment, :new_hire, company: company, primary_potential_observer: teammate)
  end
  
  before do
    sign_in_as_teammate(person, company)
  end
  
  describe 'POST #create_observation' do
    it 'redirects to observation creation with observable_moment_id' do
      post :create_observation, params: { organization_id: company.id, id: observable_moment.id }
      
      expect(response).to redirect_to(new_organization_observation_path(company, observable_moment_id: observable_moment.id))
    end
    
    it 'requires user to be the primary potential observer' do
      sign_in_as_teammate(other_person, company)
      
      post :create_observation, params: { organization_id: company.id, id: observable_moment.id }
      
      expect(response).to redirect_to(get_shit_done_organization_path(company))
      expect(flash[:alert]).to be_present
    end
  end
  
  describe 'GET #reassign' do
    it 'renders the reassign page' do
      get :reassign, params: { organization_id: company.id, id: observable_moment.id }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:observable_moment)).to eq(observable_moment)
      expect(assigns(:teammates)).to include(teammate, other_teammate)
    end
    
    it 'requires user to be the primary potential observer' do
      sign_in_as_teammate(other_person, company)
      
      get :reassign, params: { organization_id: company.id, id: observable_moment.id }
      
      expect(response).to redirect_to(get_shit_done_organization_path(company))
    end
  end
  
  describe 'PATCH #reassign' do
    it 'reassigns the moment to a new teammate' do
      patch :reassign, params: {
        organization_id: company.id,
        id: observable_moment.id,
        teammate_id: other_teammate.id
      }
      
      expect(response).to redirect_to(get_shit_done_organization_path(company))
      expect(flash[:notice]).to include('reassigned successfully')
      expect(observable_moment.reload.primary_potential_observer).to eq(other_teammate)
    end
    
    it 'rejects invalid teammate_id' do
      patch :reassign, params: {
        organization_id: company.id,
        id: observable_moment.id,
        teammate_id: 99999
      }
      
      expect(response).to redirect_to(reassign_organization_observable_moment_path(company, observable_moment))
      expect(flash[:alert]).to include('Invalid teammate')
    end
    
    it 'requires user to be the primary potential observer' do
      sign_in_as_teammate(other_person, company)
      
      patch :reassign, params: {
        organization_id: company.id,
        id: observable_moment.id,
        teammate_id: other_teammate.id
      }
      
      expect(response).to redirect_to(get_shit_done_organization_path(company))
    end
  end
  
  describe 'PATCH #ignore' do
    it 'marks the moment as processed without creating observation' do
      expect(observable_moment.processed?).to be false
      
      patch :ignore, params: { organization_id: company.id, id: observable_moment.id }
      
      expect(response).to redirect_to(get_shit_done_organization_path(company))
      expect(flash[:notice]).to include('ignored')
      expect(observable_moment.reload.processed?).to be true
      expect(observable_moment.processed_by_teammate).to eq(teammate)
      expect(observable_moment.observations.count).to eq(0)
    end
    
    it 'requires user to be the primary potential observer' do
      sign_in_as_teammate(other_person, company)
      
      patch :ignore, params: { organization_id: company.id, id: observable_moment.id }
      
      expect(response).to redirect_to(get_shit_done_organization_path(company))
      expect(observable_moment.reload.processed?).to be false
    end
  end
end

