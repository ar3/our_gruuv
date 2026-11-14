# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Feedback Request Mint', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:subject_tm) { create(:teammate, organization: organization) }
  let!(:token_record) { create(:mcp_access_token, company_teammate: teammate) }
  let(:raw_token) { token_record.raw_token_for_specs }

  before do
    teammate.update!(first_employed_at: 1.year.ago, last_terminated_at: nil)
    subject_tm.update!(first_employed_at: 1.year.ago, last_terminated_at: nil)
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: subject_tm, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:aspiration, company: organization, name: 'Integrity', department: nil)
  end

  it 'requires Bearer auth' do
    post '/api/feedback_requests/mint', params: { observed: { teammate_id: subject_tm.id }, observer: { email: 'a@b.com' } }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'mints a public FR link for an external observer' do
    post '/api/feedback_requests/mint',
         params: {
           observed: { teammate_id: subject_tm.id },
           observer: { email: 'api-client@example.com' },
           topics: 'values'
         },
         headers: { 'AUTHORIZATION' => "Bearer #{raw_token}" }

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['ok']).to be true
    expect(body.dig('data', 'public_answer_url')).to include('/f/')
    expect(body.dig('data', 'feedback_request_id')).to be_present
  end
end
