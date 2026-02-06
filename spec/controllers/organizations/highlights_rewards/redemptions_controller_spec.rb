require 'rails_helper'

RSpec.describe Organizations::HighlightsRewards::RedemptionsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:admin_person) { create(:person) }
  let(:admin_teammate) { create(:company_teammate, person: admin_person, organization: organization, can_manage_highlights_rewards: true) }
  let(:regular_person) { create(:person) }
  let(:regular_teammate) { create(:company_teammate, person: regular_person, organization: organization) }
  let(:reward) { create(:highlights_reward, organization: organization, cost_in_points: 50) }

  # Give regular user enough points
  let!(:ledger) do
    create(:highlights_points_ledger,
      company_teammate: regular_teammate,
      organization: organization,
      points_to_spend: 100.0)
  end

  describe 'GET #index' do
    context 'as regular user' do
      before { session[:current_company_teammate_id] = regular_teammate.id }

      it 'returns success' do
        get :index, params: { organization_id: organization.id }
        expect(response).to have_http_status(:success)
      end

      it 'shows only own redemptions' do
        own_redemption = create(:highlights_redemption, organization: organization, company_teammate: regular_teammate, highlights_reward: reward)
        other_redemption = create(:highlights_redemption, organization: organization, company_teammate: admin_teammate, highlights_reward: reward)

        get :index, params: { organization_id: organization.id }

        expect(assigns(:redemptions)).to include(own_redemption)
        expect(assigns(:redemptions)).not_to include(other_redemption)
        expect(assigns(:view_mode)).to eq(:user)
      end
    end

    context 'as admin' do
      before { session[:current_company_teammate_id] = admin_teammate.id }

      it 'shows all redemptions' do
        own_redemption = create(:highlights_redemption, organization: organization, company_teammate: admin_teammate, highlights_reward: reward)
        other_redemption = create(:highlights_redemption, organization: organization, company_teammate: regular_teammate, highlights_reward: reward)

        get :index, params: { organization_id: organization.id }

        expect(assigns(:redemptions)).to include(own_redemption, other_redemption)
        expect(assigns(:view_mode)).to eq(:admin)
      end
    end
  end

  describe 'GET #show' do
    context 'viewing own redemption' do
      before { session[:current_company_teammate_id] = regular_teammate.id }

      let(:redemption) { create(:highlights_redemption, organization: organization, company_teammate: regular_teammate, highlights_reward: reward) }

      it 'returns success' do
        get :show, params: { organization_id: organization.id, id: redemption.id }
        expect(response).to have_http_status(:success)
      end
    end

    context 'viewing others redemption as admin' do
      before { session[:current_company_teammate_id] = admin_teammate.id }

      let(:redemption) { create(:highlights_redemption, organization: organization, company_teammate: regular_teammate, highlights_reward: reward) }

      it 'returns success' do
        get :show, params: { organization_id: organization.id, id: redemption.id }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET #new' do
    before { session[:current_company_teammate_id] = regular_teammate.id }

    it 'returns success with reward_id' do
      get :new, params: { organization_id: organization.id, reward_id: reward.id }
      expect(response).to have_http_status(:success)
      expect(assigns(:reward)).to eq(reward)
      expect(assigns(:can_afford)).to be true
    end
  end

  describe 'POST #create' do
    before { session[:current_company_teammate_id] = regular_teammate.id }

    let(:valid_params) do
      {
        organization_id: organization.id,
        redemption: { reward_id: reward.id, notes: 'Test note' }
      }
    end

    it 'creates a redemption' do
      expect {
        post :create, params: valid_params
      }.to change(HighlightsRedemption, :count).by(1)
    end

    it 'deducts points from ledger' do
      expect {
        post :create, params: valid_params
      }.to change { ledger.reload.points_to_spend }.by(-50.0)
    end

    it 'redirects to redemption show on success' do
      post :create, params: valid_params
      expect(response).to redirect_to(organization_highlights_rewards_redemption_path(organization, HighlightsRedemption.last))
    end

    context 'with insufficient balance' do
      before { ledger.update!(points_to_spend: 10.0) }

      it 'redirects with error' do
        post :create, params: valid_params
        expect(response).to redirect_to(organization_highlights_rewards_rewards_path(organization))
        expect(flash[:alert]).to include("Insufficient points")
      end
    end
  end

  describe 'POST #fulfill' do
    before { session[:current_company_teammate_id] = admin_teammate.id }

    let(:redemption) { create(:highlights_redemption, :pending, organization: organization, company_teammate: regular_teammate, highlights_reward: reward) }

    it 'marks redemption as fulfilled' do
      post :fulfill, params: { organization_id: organization.id, id: redemption.id, external_reference: 'REF123' }
      expect(redemption.reload.status).to eq('fulfilled')
      expect(redemption.external_reference).to eq('REF123')
    end

    context 'as regular user' do
      before { session[:current_company_teammate_id] = regular_teammate.id }

      it 'denies access' do
        post :fulfill, params: { organization_id: organization.id, id: redemption.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST #cancel' do
    before { session[:current_company_teammate_id] = admin_teammate.id }

    # Use the ledger already defined for regular_teammate (avoid uniqueness conflict)
    let(:redemption) { create(:highlights_redemption, :pending, organization: organization, company_teammate: regular_teammate, highlights_reward: reward, points_spent: 50) }

    it 'marks redemption as cancelled' do
      # Ensure ledger exists
      ledger
      post :cancel, params: { organization_id: organization.id, id: redemption.id, reason: 'Test cancel' }
      expect(redemption.reload.status).to eq('cancelled')
    end

    it 'refunds points to redeemer' do
      # Start with 100 points, redemption cost 50, so after refund should be 150
      expect {
        post :cancel, params: { organization_id: organization.id, id: redemption.id, reason: 'Test cancel' }
      }.to change { ledger.reload.points_to_spend }.by(50.0)
    end
  end
end
