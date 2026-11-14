# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::Integrations', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    teammate.update!(first_employed_at: 1.year.ago, last_terminated_at: nil)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/integrations' do
    it 'renders the integrations hub with MCP and mint docs' do
      get organization_integrations_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Integrations')
      expect(response.body).to include('integrationsPageHelp')
      expect(response.body).to include('/mcp')
      expect(response.body).to include('/api/feedback_requests/mint')
      expect(response.body).to include('mint_feedback_link')
      expect(response.body).to include(organization_mcp_access_tokens_path(organization))
      expect(response.body).to include('MCP/API access tokens')
      expect(response.body).to include('Mint Feedback Request link')
      expect(response.body).to include('Example bodies')
      expect(response.body).to include('observed_teammate_id')
      expect(response.body).to include('observer_email')
      expect(response.body).to include('observer_phone')
      expect(response.body).to include('"person_id": 789')
      expect(response.body).to include('Flat field aliases')
      expect(response.body).to include('Topics')
      expect(response.body).to include('assignment:42')
      expect(response.body).to include('offer_key')
      expect(response.body).to include('object_type')
      expect(response.body).to include('feedback_request_id')
      expect(response.body).to include('Natural-language topic strings')
      expect(response.body.index('MCP/API access tokens')).to be < response.body.index('>MCP<')
    end

    it 'requires authentication' do
      sign_out_teammate_for_request
      get organization_integrations_path(organization)
      expect(response).to redirect_to(login_path)
    end
  end
end
