# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Company teammate feedback relevance offers', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:viewer_person) { create(:person) }
  let(:subject_person) { create(:person) }

  let!(:viewer) do
    ct = create(:company_teammate, organization: organization, person: viewer_person)
    ct.update!(first_employed_at: 1.year.ago)
    CompanyTeammate.find(ct.id)
  end

  let!(:subject_tm) do
    ct = create(:company_teammate, organization: organization, person: subject_person)
    ct.update!(first_employed_at: 1.month.ago)
    CompanyTeammate.find(ct.id)
  end

  let!(:value) { create(:aspiration, company: organization, name: 'Integrity', department: nil) }

  before do
    create(:employment_tenure, teammate: viewer, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: subject_tm, company: organization, started_at: 1.month.ago, ended_at: nil)
    sign_in_as_teammate_for_request(viewer_person, organization)
  end

  it 'shows relevance offers on internal and accepts values offer into answer' do
    get internal_organization_company_teammate_path(organization, subject_tm)
    expect(response).to have_http_status(:success)
    expect(response.body).to include('relevant feedback')
    expect(response.body).to include('company values')

    expect do
      post accept_feedback_offer_organization_company_teammate_path(organization, subject_tm),
           params: { offer_key: 'values' }
    end.to change(FeedbackRequest, :count).by(1)

    fr = FeedbackRequest.order(:id).last
    expect(response).to redirect_to(answer_organization_feedback_request_path(organization, fr))
    follow_redirect!
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Answer Feedback Request')
    expect(response.body).to include('Consult OG to see if we can make the questions')
  end
end
