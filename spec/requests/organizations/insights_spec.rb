require 'rails_helper'

RSpec.describe 'Organizations::Insights', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, person: person, organization: organization, first_employed_at: 1.year.ago) }

  before do
    sign_in_as_teammate_for_request(person, organization)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_observations?).and_return(true)
  end

  describe 'GET /organizations/:organization_id/insights/observations' do
    it 'returns http success' do
      get organization_insights_observations_path(organization)
      expect(response).to have_http_status(:success)
    end

    it 'renders observations insights page with chart and tables' do
      get organization_insights_observations_path(organization)
      expect(response.body).to include('Insights: Observations')
      expect(response.body).to include('Observations Kudos vs Feedback')
      expect(response.body).to include('Observations Sharing')
      expect(response.body).to include('observations-by-privacy-chart')
    end

    it 'includes timeframe filter links (Last 90 days, Last Year, All-Time)' do
      get organization_insights_observations_path(organization)
      expect(response.body).to include('Last 90 days')
      expect(response.body).to include('Last Year')
      expect(response.body).to include('All-Time')
    end

    it 'returns success with timeframe=year' do
      get organization_insights_observations_path(organization, timeframe: 'year')
      expect(response).to have_http_status(:success)
    end
  end
end
