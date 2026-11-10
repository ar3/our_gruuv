# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackRequest, type: :model do
  let(:company) { create(:organization, :company) }
  let(:requestor) { create(:company_teammate, organization: company) }
  let(:subject_teammate) { create(:company_teammate, organization: company) }
  let(:feedback_request) do
    create(:feedback_request,
      company: company,
      requestor_teammate: requestor,
      subject_of_feedback_teammate: subject_teammate,
      subject_line: 'Ship feedback'
    )
  end

  describe 'audience' do
    it 'defaults to organization' do
      expect(feedback_request).to be_organization
      expect(feedback_request).to be_open_to_organization_teammates
    end

    it 'generates a public_answer_token' do
      expect(feedback_request.public_answer_token).to be_present
    end

    it 'treats open_to_public as open to organization teammates on the org path' do
      feedback_request.update!(audience: :open_to_public)
      expect(feedback_request.reload).to be_open_to_public
      expect(feedback_request).to be_open_to_organization_teammates
      expect(feedback_request.read_attribute_before_type_cast('audience')).to eq('public')
    end

    it 'is ready with questions and no named responders when organization' do
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Q?', position: 1)
      expect(feedback_request.reload).to be_ready
      expect(feedback_request).to be_organization
      expect(feedback_request).to be_answerable
    end

    it 'is invalid without named responders when recipients_only' do
      feedback_request.update!(audience: :recipients_only)
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Q?', position: 1)
      expect(feedback_request.reload.invalid?).to be true

      responder = create(:company_teammate, organization: company)
      feedback_request.feedback_request_responders.create!(teammate: responder)
      expect(feedback_request.reload).to be_ready
      expect(feedback_request).to be_recipients_only
    end

    it 'stays ready when organization and also has named responders' do
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Q?', position: 1)
      responder = create(:company_teammate, organization: company)
      feedback_request.feedback_request_responders.create!(teammate: responder)
      expect(feedback_request.reload).to be_ready
      expect(feedback_request).to be_open_to_organization_teammates
      expect(feedback_request.responders).to include(responder)
    end
  end

  describe '#to_param' do
    it 'includes id, subject casual name, and subject line' do
      subject_teammate.person.update!(first_name: 'Andrew', last_name: 'Hall', preferred_name: 'Drew')
      feedback_request.update!(subject_line: 'Hubspot x Asana automation')
      expect(feedback_request.reload.to_param).to eq(
        "#{feedback_request.id}-drew-hubspot-x-asana-automation"
      )
    end
  end
end
