# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::HighlightsRewards routes', type: :routing do
  let(:organization_id) { '1' }

  describe 'dashboard removed' do
    it 'does not route to highlights_rewards dashboard controller' do
      # Catch-all makes path routable to missing_resources#show; we assert it does not go to dashboard
      expect(get: "/organizations/#{organization_id}/highlights_rewards/dashboard").not_to route_to(
        controller: 'organizations/highlights_rewards/dashboards',
        action: 'show',
        organization_id: organization_id
      )
    end

    it 'does not define organization_highlights_rewards_dashboard_path helper' do
      expect(Rails.application.routes.url_helpers).not_to respond_to(:organization_highlights_rewards_dashboard_path)
    end
  end

  describe 'admin routes (points and rewards)' do
    it 'routes GET highlights_rewards/bank_awards to bank_awards#index' do
      expect(get: "/organizations/#{organization_id}/highlights_rewards/bank_awards").to route_to(
        controller: 'organizations/highlights_rewards/bank_awards',
        action: 'index',
        organization_id: organization_id
      )
    end

    it 'routes GET highlights_rewards/bank_awards/new to bank_awards#new' do
      expect(get: "/organizations/#{organization_id}/highlights_rewards/bank_awards/new").to route_to(
        controller: 'organizations/highlights_rewards/bank_awards',
        action: 'new',
        organization_id: organization_id
      )
    end

    it 'generates new_organization_highlights_rewards_bank_award_path' do
      expect(new_organization_highlights_rewards_bank_award_path(organization_id)).to eq("/organizations/#{organization_id}/highlights_rewards/bank_awards/new")
    end

    it 'routes GET highlights_rewards/rewards to rewards#index' do
      expect(get: "/organizations/#{organization_id}/highlights_rewards/rewards").to route_to(
        controller: 'organizations/highlights_rewards/rewards',
        action: 'index',
        organization_id: organization_id
      )
    end

    it 'generates organization_highlights_rewards_bank_awards_path' do
      expect(organization_highlights_rewards_bank_awards_path(organization_id)).to eq("/organizations/#{organization_id}/highlights_rewards/bank_awards")
    end

    it 'generates organization_highlights_rewards_rewards_path' do
      expect(organization_highlights_rewards_rewards_path(organization_id)).to eq("/organizations/#{organization_id}/highlights_rewards/rewards")
    end
  end
end
