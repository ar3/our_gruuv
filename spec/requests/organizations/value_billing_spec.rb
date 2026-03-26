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
      expect(response.body).to include('Value / Billing')
      expect(response.body).to include('Beta')
      expect(response.body).to include('Total value attained by week')
      expect(response.body).to include('value-billing-total-chart')
      expect(response.body).to include('value-billing-milestones-chart')
      expect(response.body).to include('value-billing-observees-chart')
      expect(response.body).to include('value-billing-check-ins-chart')
      expect(response.body).to include('value-billing-goal-check-ins-chart')
    end
  end
end
