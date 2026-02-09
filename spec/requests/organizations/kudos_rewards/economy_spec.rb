# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::KudosRewards::Economy', type: :request do
  let(:organization) { create(:organization) }
  let(:admin_person) { create(:person) }
  let(:admin_teammate) do
    create(:company_teammate, person: admin_person, organization: organization, can_manage_kudos_rewards: true)
  end
  let(:regular_person) { create(:person) }
  let(:regular_teammate) { create(:company_teammate, person: regular_person, organization: organization) }

  before do
    admin_teammate
    regular_teammate
  end

  describe 'GET /organizations/:organization_id/kudos_rewards/economy' do
    context 'when user has can_manage_kudos_rewards' do
      before { sign_in_as_teammate_for_request(admin_person, organization) }

      it 'redirects to edit' do
        get organization_kudos_rewards_economy_path(organization)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(edit_organization_kudos_rewards_economy_path(organization))
      end
    end

    context 'when user does not have can_manage_kudos_rewards' do
      before { sign_in_as_teammate_for_request(regular_person, organization) }

      it 'redirects to edit' do
        get organization_kudos_rewards_economy_path(organization)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(edit_organization_kudos_rewards_economy_path(organization))
      end
    end
  end

  describe 'GET /organizations/:organization_id/kudos_rewards/economy/edit' do
    context 'when user has can_manage_kudos_rewards' do
      before { sign_in_as_teammate_for_request(admin_person, organization) }

      it 'returns success' do
        get edit_organization_kudos_rewards_economy_path(organization)
        expect(response).to have_http_status(:success)
      end

      it 'renders the edit template' do
        get edit_organization_kudos_rewards_economy_path(organization)
        expect(response).to render_template(:edit)
      end

      it 'shows economy form sections' do
        get edit_organization_kudos_rewards_economy_path(organization)
        expect(response.body).to include('Bank to Manager Allowances')
        expect(response.body).to include('Bank Automation')
        expect(response.body).to include('Weekly Guaranteed Minimum')
        expect(response.body).to include('Peer to Peer Rating Point Limits')
        expect(response.body).to include('Exceptional Ratings Minimum')
        expect(response.body).to include('Exceptional Ratings Maximum')
        expect(response.body).to include('Solid Ratings Minimum')
        expect(response.body).to include('Solid Ratings Maximum')
        expect(response.body).to include('Save economy settings')
      end

      it 'shows default values when organization has no saved config' do
        get edit_organization_kudos_rewards_economy_path(organization)
        expect(response.body.scan('value="250"').size).to be >= 6
        expect(response.body.scan('value="100"').size).to be >= 3
        expect(response.body).to include('value="30"')
        expect(response.body).to include('value="50"')
        expect(response.body).to include('value="5"')
        expect(response.body).to include('value="25"')
      end
    end

    context 'when user does not have can_manage_kudos_rewards' do
      before { sign_in_as_teammate_for_request(regular_person, organization) }

      it 'returns success and shows read-only economy page' do
        get edit_organization_kudos_rewards_economy_path(organization)
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:edit)
      end

      it 'shows disabled form fields, disabled Save button, and warning icon with tooltip' do
        get edit_organization_kudos_rewards_economy_path(organization)
        expect(response.body).to include('Bank to Manager Allowances')
        expect(response.body).to include('Save economy settings')
        expect(response.body).to include('disabled')
        expect(response.body).to include('bi-exclamation-triangle')
        expect(response.body).to include('data-bs-toggle')
        expect(response.body).to include('kudos points management permission')
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/kudos_rewards/economy' do
    context 'when user has can_manage_kudos_rewards' do
      before { sign_in_as_teammate_for_request(admin_person, organization) }

      it 'updates kudos_points_economy_config and redirects with notice' do
        patch organization_kudos_rewards_economy_path(organization),
              params: {
                economy: {
                  ability_milestone: { points_to_give: '20', points_to_spend: '10' },
                  seat_change: { points_to_give: '25', points_to_spend: '10' },
                  bank_automation: { weekly_guaranteed_minimum_to_give: '75' },
                  peer_to_peer_rating_limits: {
                    exceptional_ratings_min: '40',
                    exceptional_ratings_max: '60',
                    solid_ratings_min: '10',
                    solid_ratings_max: '30'
                  }
                }
              }

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(edit_organization_kudos_rewards_economy_path(organization))
        expect(flash[:notice]).to eq('Economy settings saved.')

        organization.reload
        expect(organization.kudos_points_economy_config['ability_milestone']['points_to_give']).to eq('20')
        expect(organization.kudos_points_economy_config['ability_milestone']['points_to_spend']).to eq('10')
        expect(organization.kudos_points_economy_config['seat_change']['points_to_give']).to eq('25')
        expect(organization.kudos_points_economy_config['seat_change']['points_to_spend']).to eq('10')
        expect(organization.kudos_points_economy_config['weekly_guaranteed_minimum_to_give']).to eq('75')
        expect(organization.kudos_points_economy_config['peer_to_peer_rating_limits']['exceptional_ratings_min']).to eq('40')
        expect(organization.kudos_points_economy_config['peer_to_peer_rating_limits']['exceptional_ratings_max']).to eq('60')
        expect(organization.kudos_points_economy_config['peer_to_peer_rating_limits']['solid_ratings_min']).to eq('10')
        expect(organization.kudos_points_economy_config['peer_to_peer_rating_limits']['solid_ratings_max']).to eq('30')
      end
    end

    context 'when user does not have can_manage_kudos_rewards' do
      before { sign_in_as_teammate_for_request(regular_person, organization) }

      it 'redirects to root and does not update config' do
        patch organization_kudos_rewards_economy_path(organization),
              params: {
                economy: {
                  ability_milestone: { points_to_give: '99', points_to_spend: '99' }
                }
              }

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        organization.reload
        expect(organization.kudos_points_economy_config['ability_milestone']).not_to eq({ 'points_to_give' => '99', 'points_to_spend' => '99' })
      end
    end
  end
end
