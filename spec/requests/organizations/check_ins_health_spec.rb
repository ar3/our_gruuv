# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Check-ins Health', type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil, can_manage_employment: true)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/check_ins_health' do
    it 'returns success and shows filter and table' do
      get organization_check_ins_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Check-ins Health')
      expect(response.body).to include('Who to show')
      expect(response.body).to include('Aspirations')
      expect(response.body).to include('Assignments')
      expect(response.body).to include('Position')
      expect(response.body).to include('Milestones')
    end

    it 'with manager_id=just_me returns success' do
      get organization_check_ins_health_path(company), params: { manager_id: 'just_me' }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /organizations/:organization_id/check_ins_health_export' do
    it 'returns CSV attachment' do
      get organization_check_ins_health_export_path(company)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')
    end
  end
end
