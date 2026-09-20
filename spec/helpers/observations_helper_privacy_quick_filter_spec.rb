require 'rails_helper'

RSpec.describe ObservationsHelper, 'privacy quick filter', type: :helper do
  describe '#observation_privacy_quick_filter_selection' do
    it 'returns :all when privacy is blank' do
      expect(helper.observation_privacy_quick_filter_selection({})).to eq(:all)
      expect(helper.observation_privacy_quick_filter_selection({ privacy: [] })).to eq(:all)
    end

    it 'returns :public for exactly the two public levels' do
      expect(
        helper.observation_privacy_quick_filter_selection(
          privacy: %w[public_to_world public_to_company]
        )
      ).to eq(:public)
    end

    it 'returns :private for exactly the four private levels' do
      expect(
        helper.observation_privacy_quick_filter_selection(
          privacy: ObservationsHelper::PRIVATE_PRIVACY_QUICK_FILTER.reverse
        )
      ).to eq(:private)
    end

    it 'returns :custom for partial or mixed privacy sets' do
      expect(helper.observation_privacy_quick_filter_selection(privacy: %w[public_to_company])).to eq(:custom)
      expect(
        helper.observation_privacy_quick_filter_selection(
          privacy: %w[public_to_company observer_only]
        )
      ).to eq(:custom)
      expect(
        helper.observation_privacy_quick_filter_selection(
          privacy: ObservationsHelper::PUBLIC_PRIVACY_QUICK_FILTER + ObservationsHelper::PRIVATE_PRIVACY_QUICK_FILTER
        )
      ).to eq(:custom)
    end
  end

  describe '#observation_privacy_quick_filter_path' do
    let(:organization) { create(:organization) }

    before do
      controller.params = ActionController::Parameters.new(
        controller: 'organizations/observations',
        action: 'index',
        organization_id: organization.to_param,
        timeframe: 'this_week',
        privacy: ['observer_only']
      )
    end

    it 'builds an Only Public path and drops the prior privacy set' do
      path = helper.observation_privacy_quick_filter_path(organization, :public)
      expect(path).to include('privacy')
      expect(path).to include('public_to_company')
      expect(path).to include('public_to_world')
      expect(path).to include('timeframe=this_week')
      expect(path).not_to include('observer_only')
    end

    it 'clears privacy for All Privacy Levels' do
      path = helper.observation_privacy_quick_filter_path(organization, :all)
      expect(path).not_to include('privacy')
      expect(path).to include('timeframe=this_week')
    end
  end
end
