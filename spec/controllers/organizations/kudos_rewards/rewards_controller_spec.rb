require 'rails_helper'

RSpec.describe Organizations::KudosRewards::RewardsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:admin_person) { create(:person) }
  let(:admin_teammate) { create(:company_teammate, person: admin_person, organization: organization, can_manage_kudos_rewards: true) }
  let(:regular_person) { create(:person) }
  let(:regular_teammate) { create(:company_teammate, person: regular_person, organization: organization) }
  let(:reward) { create(:kudos_reward, organization: organization) }

  describe 'GET #index' do
    context 'as admin' do
      before { session[:current_company_teammate_id] = admin_teammate.id }

      it 'returns success' do
        get :index, params: { organization_id: organization.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns rewards' do
        reward
        get :index, params: { organization_id: organization.id }
        expect(assigns(:rewards)).to include(reward)
      end
    end

    context 'as regular user' do
      before { session[:current_company_teammate_id] = regular_teammate.id }

      it 'returns success' do
        get :index, params: { organization_id: organization.id }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET #show' do
    before { session[:current_company_teammate_id] = regular_teammate.id }

    it 'returns success' do
      get :show, params: { organization_id: organization.id, id: reward.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #new' do
    context 'as admin' do
      before { session[:current_company_teammate_id] = admin_teammate.id }

      it 'returns success' do
        get :new, params: { organization_id: organization.id }
        expect(response).to have_http_status(:success)
      end
    end

    context 'as regular user' do
      before { session[:current_company_teammate_id] = regular_teammate.id }

      it 'denies access' do
        get :new, params: { organization_id: organization.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST #create' do
    before { session[:current_company_teammate_id] = admin_teammate.id }

    let(:valid_params) do
      {
        organization_id: organization.id,
        kudos_reward: {
          name: 'New Reward',
          cost_in_points: 100,
          reward_type: 'gift_card',
          active: true
        }
      }
    end

    it 'creates a new reward' do
      expect {
        post :create, params: valid_params
      }.to change(KudosReward, :count).by(1)
    end

    it 'redirects to rewards index on success' do
      post :create, params: valid_params
      expect(response).to redirect_to(organization_kudos_rewards_rewards_path(organization))
    end

    it 'renders new on failure' do
      post :create, params: { organization_id: organization.id, kudos_reward: { name: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH #update' do
    before { session[:current_company_teammate_id] = admin_teammate.id }

    it 'updates the reward' do
      patch :update, params: { organization_id: organization.id, id: reward.id, kudos_reward: { name: 'Updated Name' } }
      expect(reward.reload.name).to eq('Updated Name')
    end

    it 'redirects to rewards index on success' do
      patch :update, params: { organization_id: organization.id, id: reward.id, kudos_reward: { name: 'Updated Name' } }
      expect(response).to redirect_to(organization_kudos_rewards_rewards_path(organization))
    end
  end

  describe 'DELETE #destroy' do
    before { session[:current_company_teammate_id] = admin_teammate.id }

    it 'soft deletes the reward' do
      reward
      expect {
        delete :destroy, params: { organization_id: organization.id, id: reward.id }
      }.to change { reward.reload.deleted? }.from(false).to(true)
    end

    it 'redirects to rewards index' do
      delete :destroy, params: { organization_id: organization.id, id: reward.id }
      expect(response).to redirect_to(organization_kudos_rewards_rewards_path(organization))
    end
  end

  describe 'POST #restore' do
    before { session[:current_company_teammate_id] = admin_teammate.id }

    let(:deleted_reward) { create(:kudos_reward, :deleted, organization: organization) }

    it 'restores the reward' do
      expect {
        post :restore, params: { organization_id: organization.id, id: deleted_reward.id }
      }.to change { deleted_reward.reload.deleted? }.from(true).to(false)
    end
  end

end
