# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::KudosRewards routes', type: :routing do
  let(:organization_id) { '1' }

  describe 'dashboard removed' do
    it 'does not route to kudos_rewards dashboard controller' do
      expect(get: "/organizations/#{organization_id}/kudos_rewards/dashboard").not_to route_to(
        controller: 'organizations/kudos_rewards/dashboards',
        action: 'show',
        organization_id: organization_id
      )
    end

    it 'does not define organization_kudos_rewards_dashboard_path helper' do
      expect(Rails.application.routes.url_helpers).not_to respond_to(:organization_kudos_rewards_dashboard_path)
    end
  end

  describe 'admin routes (points and rewards)' do
    it 'routes GET kudos_rewards/bank_awards to bank_awards#index' do
      expect(get: "/organizations/#{organization_id}/kudos_rewards/bank_awards").to route_to(
        controller: 'organizations/kudos_rewards/bank_awards',
        action: 'index',
        organization_id: organization_id
      )
    end

    it 'routes GET kudos_rewards/bank_awards/new to bank_awards#new' do
      expect(get: "/organizations/#{organization_id}/kudos_rewards/bank_awards/new").to route_to(
        controller: 'organizations/kudos_rewards/bank_awards',
        action: 'new',
        organization_id: organization_id
      )
    end

    it 'generates new_organization_kudos_rewards_bank_award_path' do
      expect(new_organization_kudos_rewards_bank_award_path(organization_id)).to eq("/organizations/#{organization_id}/kudos_rewards/bank_awards/new")
    end

    it 'routes GET kudos_rewards/rewards to rewards#index' do
      expect(get: "/organizations/#{organization_id}/kudos_rewards/rewards").to route_to(
        controller: 'organizations/kudos_rewards/rewards',
        action: 'index',
        organization_id: organization_id
      )
    end

    it 'generates organization_kudos_rewards_bank_awards_path' do
      expect(organization_kudos_rewards_bank_awards_path(organization_id)).to eq("/organizations/#{organization_id}/kudos_rewards/bank_awards")
    end

    it 'generates organization_kudos_rewards_rewards_path' do
      expect(organization_kudos_rewards_rewards_path(organization_id)).to eq("/organizations/#{organization_id}/kudos_rewards/rewards")
    end
  end
end
