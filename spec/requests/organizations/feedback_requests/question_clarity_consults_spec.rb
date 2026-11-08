# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Feedback request question clarity consults', type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:requestor) { create(:company_teammate, organization: organization, person: person) }
  let(:subject_tm) { create(:company_teammate, organization: organization) }
  let(:feedback_request) do
    create(:feedback_request, :ready, company: organization, requestor_teammate: requestor, subject_of_feedback_teammate: subject_tm)
  end

  before do
    create(:employment_tenure, teammate: requestor, company: organization, ended_at: nil)
    sign_in_as_teammate_for_request(person, organization)
  end

  it 'starts a billable consult once from the show page' do
    expect do
      post question_clarity_consult_organization_feedback_request_path(organization, feedback_request)
    end.to change(OgConsultation, :count).by(1)

    consult = feedback_request.reload.latest_question_clarity_consultation
    expect(consult).to be_present
    expect(consult.billable).to eq(true)
    expect(consult.kind).to eq(OgConsultation::KIND_FEEDBACK_REQUEST_QUESTION_CLARITY)
    expect(FeedbackRequestQuestionClarityJob).to have_been_enqueued.with(feedback_request.id, consult.id)

    expect do
      post question_clarity_consult_organization_feedback_request_path(organization, feedback_request)
    end.not_to change(OgConsultation, :count)
  end

  it 'shows completed suggestions open by default on show' do
    question = feedback_request.feedback_request_questions.first
    create_feedback_request_question_clarity_consultation!(
      feedback_request: feedback_request,
      status: 'completed',
      payload: {
        'summary' => 'Sharper prompts',
        'suggestions' => [
          {
            'feedback_request_question_id' => question.id,
            'suggested_question_text' => 'Tell a specific story…',
            'rationale' => 'More concrete'
          }
        ]
      }
    )

    get organization_feedback_request_path(organization, feedback_request)
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Show what OG thinks will make the questions')
    expect(response.body).to include('OG tries to make it more clear')
    expect(response.body).to include('Tell a specific story')
    # Per-question suggestion blocks are open by default after a completed consult.
    expect(response.body).to match(/data-fr-question-clarity-consult-target="suggestion"/)
    expect(response.body).not_to match(/data-fr-question-clarity-consult-target="suggestion"[^>]*class="[^"]*d-none/)
  end
end

