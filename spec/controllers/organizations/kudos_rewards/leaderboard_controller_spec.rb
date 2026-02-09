# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::KudosRewards::LeaderboardController, type: :controller do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    session[:current_company_teammate_id] = teammate.id
    allow(controller).to receive(:organization).and_return(organization)
  end

  describe 'GET #show' do
    it 'returns success' do
      get :show, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
    end

    it 'defaults timeframe to 90_days' do
      get :show, params: { organization_id: organization.id }
      expect(assigns(:timeframe)).to eq(:'90_days')
    end

    it 'accepts timeframe year' do
      get :show, params: { organization_id: organization.id, timeframe: 'year' }
      expect(assigns(:timeframe)).to eq(:year)
    end

    it 'accepts timeframe all_time' do
      get :show, params: { organization_id: organization.id, timeframe: 'all_time' }
      expect(assigns(:timeframe)).to eq(:all_time)
    end

    it 'assigns top_gifters and top_recipients' do
      get :show, params: { organization_id: organization.id }
      expect(assigns(:top_gifters)).to eq([])
      expect(assigns(:top_recipients)).to eq([])
    end

    it 'includes transaction counts and from_teammates/from_bank breakdown for gifters' do
      observation = create(:observation, company: organization, observer: teammate.person, published_at: Time.current)
      create(:observee, observation: observation, company_teammate: teammate)
      other_teammate = create(:company_teammate, person: create(:person), organization: organization)
      create(:observer_give_transaction, company_teammate: teammate, organization: organization, observation: observation, points_to_give_delta: -10, points_to_spend_delta: 0)

      get :show, params: { organization_id: organization.id, timeframe: 'all_time' }

      expect(assigns(:top_gifters).length).to eq(1)
      entry = assigns(:top_gifters).first
      expect(entry).to include(:company_teammate, :total_given, :transaction_count, :from_teammates_count, :from_bank_count)
      expect(entry[:total_given]).to eq(10.0)
      expect(entry[:transaction_count]).to eq(1)
      expect(entry[:from_teammates_count]).to eq(1)
      expect(entry[:from_bank_count]).to eq(0)
    end

    it 'includes transaction counts and from_teammates/from_bank breakdown for recipients' do
      recipient = create(:company_teammate, person: create(:person), organization: organization)
      create(:points_exchange_transaction, company_teammate: recipient, organization: organization, points_to_give_delta: 0, points_to_spend_delta: 5)
      get :show, params: { organization_id: organization.id, timeframe: 'all_time' }
      expect(assigns(:top_recipients).length).to eq(1)
      entry = assigns(:top_recipients).first
      expect(entry).to include(:company_teammate, :total_received, :transaction_count, :from_teammates_count, :from_bank_count)
      expect(entry[:transaction_count]).to eq(1)
    end

    it 'renders show template' do
      get :show, params: { organization_id: organization.id }
      expect(response).to render_template(:show)
    end
  end
end
