# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackRequests::StartQuestionClarityConsult do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:requestor) { create(:company_teammate, organization: organization) }
  let(:feedback_request) { create(:feedback_request, :ready, company: organization, requestor_teammate: requestor) }

  it 'creates a pending billable consultation and enqueues the job' do
    result = described_class.call(
      feedback_request: feedback_request,
      triggered_by_teammate: requestor
    )

    expect(result).to be_ok
    expect(result.consultation.billable).to eq(true)
    expect(result.consultation.status).to eq('pending')
    expect(FeedbackRequestQuestionClarityJob).to have_been_enqueued
  end

  it 'does not create a second consultation when one already completed' do
    create_feedback_request_question_clarity_consultation!(feedback_request: feedback_request, status: 'completed')

    expect do
      described_class.call(feedback_request: feedback_request, triggered_by_teammate: requestor)
    end.not_to change(OgConsultation, :count)
  end
end
