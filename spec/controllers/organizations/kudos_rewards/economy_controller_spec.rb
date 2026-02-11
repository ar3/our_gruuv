# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::KudosRewards::EconomyController, type: :controller do
  let(:organization) { create(:organization) }
  let(:admin_person) { create(:person) }
  let(:admin_teammate) { create(:company_teammate, person: admin_person, organization: organization, can_manage_kudos_rewards: true) }
  let(:regular_teammate) { create(:company_teammate, person: create(:person), organization: organization) }

  before do
    allow(controller).to receive(:organization).and_return(organization)
  end

  describe 'GET #show' do
    before { session[:current_company_teammate_id] = admin_teammate.id }

    it 'redirects to edit' do
      get :show, params: { organization_id: organization.id }
      expect(response).to redirect_to(edit_organization_kudos_rewards_economy_path(organization))
    end
  end

  describe 'GET #edit' do
    before { session[:current_company_teammate_id] = admin_teammate.id }

    it 'returns success' do
      get :edit, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns organization and config with defaults merged' do
      get :edit, params: { organization_id: organization.id }
      expect(assigns(:organization)).to eq(organization)
      expect(assigns(:config)).to be_a(Hash)
      expect(assigns(:config)['ability_milestone']['points_to_give']).to eq('250')
      expect(assigns(:config)['weekly_guaranteed_minimum_to_give']).to eq('100')
      expect(assigns(:config)['peer_to_peer_rating_limits']['exceptional_ratings_min']).to eq('30')
      expect(assigns(:config)['birthday']['points_to_give']).to eq('250')
      expect(assigns(:config)['birthday']['points_to_spend']).to eq('250')
      expect(assigns(:config)['work_anniversary']['points_to_give']).to eq('250')
      expect(assigns(:config)['work_anniversary']['points_to_spend']).to eq('250')
    end
  end

  describe 'PATCH #update' do
    before { session[:current_company_teammate_id] = admin_teammate.id }

    it 'updates kudos_points_economy_config and redirects' do
      patch :update, params: {
        organization_id: organization.id,
        economy: {
          ability_milestone: { points_to_give: '20', points_to_spend: '10' },
          seat_change: { points_to_give: '25', points_to_spend: '10' },
          birthday: { points_to_give: '100', points_to_spend: '100' },
          work_anniversary: { points_to_give: '150', points_to_spend: '150' },
          bank_automation: { weekly_guaranteed_minimum_to_give: '75' },
          peer_to_peer_rating_limits: { exceptional_ratings_min: '40', exceptional_ratings_max: '60', solid_ratings_min: '10', solid_ratings_max: '30' }
        }
      }
      expect(response).to redirect_to(edit_organization_kudos_rewards_economy_path(organization))
      expect(flash[:notice]).to eq('Economy settings saved.')
      organization.reload
      expect(organization.kudos_points_economy_config['ability_milestone']['points_to_give']).to eq('20')
      expect(organization.kudos_points_economy_config['ability_milestone']['points_to_spend']).to eq('10')
      expect(organization.kudos_points_economy_config['birthday']['points_to_give']).to eq('100')
      expect(organization.kudos_points_economy_config['birthday']['points_to_spend']).to eq('100')
      expect(organization.kudos_points_economy_config['work_anniversary']['points_to_give']).to eq('150')
      expect(organization.kudos_points_economy_config['work_anniversary']['points_to_spend']).to eq('150')
      expect(organization.kudos_points_economy_config['weekly_guaranteed_minimum_to_give']).to eq('75')
      expect(organization.kudos_points_economy_config['peer_to_peer_rating_limits']['exceptional_ratings_min']).to eq('40')
    end

    it 'updates disable_kudos_points in config when present' do
      patch :update, params: {
        organization_id: organization.id,
        economy: {
          disable_kudos_points: '1',
          ability_milestone: { points_to_give: '20', points_to_spend: '10' },
          bank_automation: { weekly_guaranteed_minimum_to_give: '75' },
          peer_to_peer_rating_limits: { exceptional_ratings_min: '40', exceptional_ratings_max: '60', solid_ratings_min: '10', solid_ratings_max: '30' }
        }
      }
      organization.reload
      expect(organization.kudos_points_economy_config['disable_kudos_points']).to eq('true')
      expect(organization.kudos_points_disabled?).to be true
    end
  end

  context 'as regular user without manage_rewards' do
    before { session[:current_company_teammate_id] = regular_teammate.id }

    it 'allows edit (read-only view) and assigns organization and config' do
      get :edit, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
      expect(assigns(:organization)).to eq(organization)
      expect(assigns(:config)).to be_a(Hash)
    end

    it 'denies update' do
      patch :update, params: {
        organization_id: organization.id,
        economy: { ability_milestone: { points_to_give: '99', points_to_spend: '99' } }
      }
      expect(response).to redirect_to(root_path)
    end
  end
end
