# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackRequests::AcceptSystemOffer do
  let(:organization) { create(:organization, :company) }
  let(:viewer) { create(:company_teammate, organization: organization) }
  let(:subject_tm) { create(:company_teammate, organization: organization) }
  let!(:value) { create(:aspiration, company: organization, name: 'Integrity', department: nil) }

  it 'creates a shared system feedback request and names the clicker' do
    result = described_class.call(
      organization: organization,
      subject: subject_tm,
      viewer: viewer,
      offer_key: 'values'
    )

    expect(result).to be_ok
    fr = result.feedback_request
    expect(fr).to be_system_generated
    expect(fr.system_offer_key).to eq('values')
    expect(fr.open_to_anyone).to eq(false)
    expect(fr.responders).to include(viewer)
    expect(fr.feedback_request_questions.map(&:rateable)).to include(value)
  end

  it 'reuses an existing system request and adds a second named respondent' do
    first = described_class.call(
      organization: organization,
      subject: subject_tm,
      viewer: viewer,
      offer_key: 'values'
    ).feedback_request
    other = create(:company_teammate, organization: organization)

    second = described_class.call(
      organization: organization,
      subject: subject_tm,
      viewer: other,
      offer_key: 'values'
    )

    expect(second).to be_ok
    expect(second.feedback_request.id).to eq(first.id)
    expect(second.feedback_request.responders).to include(viewer, other)
  end
end
