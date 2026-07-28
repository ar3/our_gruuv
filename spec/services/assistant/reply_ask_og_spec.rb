# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::ReplyAskOg, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "appends a user message and re-queues the job" do
    started = Assistant::StartAskOg.call(
      organization: organization,
      company_teammate: teammate,
      query: "first question"
    )
    consultation = started.value[:consultation]
    consultation.update!(status: "completed", completed_at: Time.current, units_completed: 1)

    expect {
      result = described_class.call(og_consultation: consultation, message: "follow up")
      expect(result.ok?).to be(true)
    }.to have_enqueued_job(AskOgJob)

    consultation.reload
    expect(consultation.status).to eq("pending")
    expect(consultation.result.ask_og_messages.user_messages.count).to eq(2)
    expect(consultation.result.ask_og_messages.ordered.last.body).to eq("follow up")
  end
end
