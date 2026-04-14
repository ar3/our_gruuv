require 'rails_helper'

RSpec.describe 'Organizations::ValueBilling', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/value_billing' do
    it 'returns http success' do
      get organization_value_billing_path(organization)
      expect(response).to have_http_status(:success)
    end

    it 'renders the value and billing page content with charts' do
      get organization_value_billing_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Value / Billing')
      expect(response.body).to include('Beta')
      expect(response.body).to include('Clarity leads to both personal and team growth.')
      expect(response.body).to include('OG helped')
      expect(response.body).to include('Which is valued at')
      expect(response.body).to include('OGO Stories Captured')
      expect(response.body).to include('Clarity Check-ins Completed')
      expect(response.body).to include('Demonstrated Abilities Recognized')
      expect(response.body).to include('Goals Progressed')
      expect(response.body).to include('How value is calculated')
      expect(response.body).to include('data-bs-toggle="tooltip"')
      expect(response.body).to include('Total value attained by week')
      expect(response.body).to include('Last 90 Days')
      expect(response.body).to include('Last 90 days')
      expect(response.body).to include('Custom')
      expect(response.body).to include('value-billing-total-chart')
      expect(response.body).to include('value-billing-milestones-chart')
      expect(response.body).to include('value-billing-observees-chart')
      expect(response.body).to include('value-billing-check-ins-chart')
      expect(response.body).to include('value-billing-goal-check-ins-chart')
    end

    it 'accepts timeframe param like Insights' do
      get organization_value_billing_path(organization, timeframe: 'year')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Last Year')
    end

    it 'shows per-employee value or no-teammates message when there are no active teammates' do
      get organization_value_billing_path(organization)
      expect(response.body).to match(/weekly clarity value per active teammate|No active teammates/)
    end
  end
end
