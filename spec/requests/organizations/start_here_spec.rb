# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::StartHere', type: :request do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/start_here' do
    it 'returns http success' do
      get organization_start_here_path(company)
      expect(response).to have_http_status(:success)
    end

    it 'renders Start Here with title and CTA cards' do
      get organization_start_here_path(company)
      expect(response.body).to include('Start Here')
      expect(response.body).to include('quick guide')
      expect(response.body).to include('About')
      expect(response.body).to include('Get Shit Done')
      expect(response.body).to include('Kudos')
      expect(response.body).to include('Insights')
    end

    it 'uses org label for get_shit_done when set' do
      create(:company_label_preference, company: company, label_key: 'get_shit_done', label_value: 'Action Items')
      get organization_start_here_path(company)
      expect(response.body).to include('Action Items')
    end
  end
end
