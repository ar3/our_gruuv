# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentTools::MintFeedbackLink, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:subject_person) { create(:person) }
  let(:subject_tm) { create(:teammate, person: subject_person, organization: organization) }
  let(:context) do
    AgentTools::Context.new(
      organization: organization,
      person: person,
      company_teammate: teammate
    )
  end

  before do
    teammate.update!(first_employed_at: 1.year.ago, last_terminated_at: nil)
    subject_tm.update!(first_employed_at: 1.year.ago, last_terminated_at: nil)
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: subject_tm, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:aspiration, company: organization, name: 'Integrity', department: nil)
  end

  it 'mints via nested observed/observer hashes' do
    result = described_class.call(
      context: context,
      observed: { teammate_id: subject_tm.id },
      observer: { email: 'zapier-client@example.com' },
      topics: 'values'
    )

    expect(result.ok?).to be(true), -> { result.error.inspect }
    expect(result.data[:feedback_request_id]).to be_present
    expect(result.data[:public_answer_url]).to include('/f/')
    expect(result.data[:observer][:external]).to be true
  end

  it 'mints via flat aliases' do
    result = described_class.call(
      context: context,
      observed_teammate_id: subject_tm.id,
      observer_email: 'flat-client@example.com',
      topics: { offer_key: 'values' }
    )

    expect(result.ok?).to be(true), -> { result.error.inspect }
    expect(result.data[:created]).to be true
  end
end
