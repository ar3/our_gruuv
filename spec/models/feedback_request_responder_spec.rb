# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackRequestResponder, type: :model do
  describe 'completed_at' do
    let(:feedback_request) { create(:feedback_request) }
    let(:teammate) { create(:company_teammate, organization: feedback_request.company) }
    let(:responder) do
      feedback_request.feedback_request_responders.create!(teammate: teammate)
    end

    it 'defaults to nil' do
      expect(responder.completed_at).to be_nil
    end

    it 'can be set to a timestamp' do
      responder.update!(completed_at: Time.current)
      expect(responder.reload.completed_at).to be_within(5.seconds).of(Time.current)
    end

    it 'can be cleared to nil' do
      responder.update!(completed_at: Time.current)
      responder.update!(completed_at: nil)
      expect(responder.reload.completed_at).to be_nil
    end
  end
end
