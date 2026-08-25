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

  describe 'open_to_anyone' do
    it 'defaults to true' do
      expect(feedback_request.open_to_anyone).to be true
    end

    it 'is ready with questions and no named responders when open' do
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Q?', position: 1)
      expect(feedback_request.reload).to be_ready
      expect(feedback_request).to be_open_to_anyone
      expect(feedback_request).to be_answerable
    end

    it 'is invalid without named responders when closed' do
      feedback_request.update!(open_to_anyone: false)
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Q?', position: 1)
      expect(feedback_request.reload.invalid?).to be true

      responder = create(:company_teammate, organization: company)
      feedback_request.feedback_request_responders.create!(teammate: responder)
      expect(feedback_request.reload).to be_ready
      expect(feedback_request).not_to be_open_to_anyone
    end

    it 'stays ready when open and also has named responders' do
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Q?', position: 1)
      responder = create(:company_teammate, organization: company)
      feedback_request.feedback_request_responders.create!(teammate: responder)
      expect(feedback_request.reload).to be_ready
      expect(feedback_request).to be_open_to_anyone
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

  describe '.find_by_param' do
    it 'finds by numeric id' do
      expect(described_class.find_by_param(feedback_request.id.to_s)).to eq(feedback_request)
    end

    it 'finds by id-slug and ignores the human-readable suffix' do
      expect(described_class.find_by_param("#{feedback_request.id}-andrew-hall-hubspot-x-asana")).to eq(feedback_request)
    end
  end
end
