# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackRequests::MintLink do
  let(:organization) { create(:organization, :company) }
  let(:acting) { create(:company_teammate, organization: organization) }
  let(:subject_tm) { create(:company_teammate, organization: organization) }
  let!(:value) { create(:aspiration, company: organization, name: 'Integrity', department: nil) }

  def mint(**kwargs)
    described_class.call(
      organization: organization,
      acting_teammate: acting,
      **kwargs
    )
  end

  it 'mints a public link for an external observer by email (creates Person stub)' do
    result = mint(
      observed: { teammate_id: subject_tm.id },
      observer: { email: 'client@example.com' },
      topics: 'values'
    )

    expect(result.ok?).to be(true), -> { result.error.inspect }
    expect(result.created).to be true
    expect(result.created_person).to be true
    expect(result.observer_teammate).to be_nil
    expect(result.feedback_request).to be_open_to_public
    expect(result.feedback_request.system_offer_key).to eq('values')

    payload = described_class.new(
      organization: organization,
      acting_teammate: acting,
      observed: {},
      observer: {}
    ).link_payload(result)
    expect(payload[:public_answer_url]).to include('/f/')
    expect(payload[:answer_url]).to be_present
  end

  it 'reuses an existing system FR and returns org answer path for teammate observers' do
    observer = create(:company_teammate, organization: organization)
    first = mint(
      observed: { teammate_id: subject_tm.id },
      observer: { teammate_id: observer.id },
      topics: 'values'
    )
    expect(first.ok?).to be(true), -> { first.error.inspect }
    expect(first.created).to be true

    second = mint(
      observed: { teammate_id: subject_tm.id },
      observer: { teammate_id: observer.id },
      topics: 'values'
    )
    expect(second.ok?).to be true
    expect(second.created).to be false
    expect(second.feedback_request.id).to eq(first.feedback_request.id)
    expect(second.feedback_request).to be_recipients_only

    payload = described_class.new(
      organization: organization,
      acting_teammate: acting,
      observed: {},
      observer: {}
    ).link_payload(second)
    expect(payload[:public_answer_url]).to be_nil
    expect(payload[:answer_path]).to include('/answer')
  end

  it 'resolves observed by email' do
    result = mint(
      observed: { email: subject_tm.person.email },
      observer: { email: 'other@example.com' },
      topics: 'values'
    )
    expect(result.ok?).to be(true), -> { result.error.inspect }
    expect(result.observed.id).to eq(subject_tm.id)
  end

  it 'fails clearly when observed is missing' do
    result = mint(
      observed: { email: 'nobody@example.com' },
      observer: { email: 'client@example.com' },
      topics: 'values'
    )
    expect(result.ok?).to be false
    expect(result.error_code).to eq('not_found')
  end

  it 'rejects observer == observed teammate' do
    result = mint(
      observed: { teammate_id: subject_tm.id },
      observer: { teammate_id: subject_tm.id },
      topics: 'values'
    )
    expect(result.ok?).to be false
    expect(result.error_code).to eq('validation_failed')
  end
end
