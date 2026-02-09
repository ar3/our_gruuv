# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::KudosRewards::BankAwardsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:admin_teammate) { create(:company_teammate, person: create(:person), organization: organization, can_manage_kudos_rewards: true) }

  before do
    session[:current_company_teammate_id] = admin_teammate.id
    allow(controller).to receive(:organization).and_return(organization)
  end

  describe 'GET #index' do
    it 'returns success' do
      get :index, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns recent_awards' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:recent_awards)).to be_a(ActiveRecord::Relation)
    end

    it 'assigns total_points_to_give and total_points_to_redeem from ledgers' do
      create(:kudos_points_ledger, organization: organization, company_teammate: admin_teammate, points_to_give: 50.0, points_to_spend: 25.0)
      other = create(:company_teammate, person: create(:person), organization: organization)
      create(:kudos_points_ledger, organization: organization, company_teammate: other, points_to_give: 10.0, points_to_spend: 5.0)

      get :index, params: { organization_id: organization.id }

      expect(assigns(:total_points_to_give)).to eq(60.0)
      expect(assigns(:total_points_to_redeem)).to eq(30.0)
    end
  end

  context 'when teammate does not have can_manage_kudos_rewards' do
    let(:regular_teammate) { create(:company_teammate, person: create(:person), organization: organization, can_manage_kudos_rewards: false) }

    before do
      session[:current_company_teammate_id] = regular_teammate.id
    end

    describe 'GET #index' do
      it 'returns success' do
        get :index, params: { organization_id: organization.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns recent_awards' do
        get :index, params: { organization_id: organization.id }
        expect(assigns(:recent_awards)).to be_a(ActiveRecord::Relation)
      end
    end
  end
end
