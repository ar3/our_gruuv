# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::PeriodBriefRunner do
  let(:organization) { create(:organization, :company) }
  let(:viewer_person) { create(:person, first_name: "Alex") }
  let(:viewer) { create(:teammate, person: viewer_person, organization: organization) }
  let(:employee_person) { create(:person, first_name: "Pat") }
  let(:employee) { create(:teammate, person: employee_person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Ship weekly demos") }
  let(:check_in) do
    create(
      :assignment_check_in,
      teammate: employee,
      assignment: assignment,
      check_in_started_on: Date.current,
      official_check_in_completed_at: nil
    )
  end
  let(:consultation) do
    create_check_in_period_brief_consultation!(
      check_in: check_in,
      status: "processing",
      triggered_by_teammate: viewer
    )
  end

  before do
    create(:assignment_tenure, company_teammate: employee, assignment: assignment, started_at: 30.days.ago)
    allow(RubyLLM.config).to receive_messages(
      bedrock_api_key: "key",
      bedrock_secret_key: "secret",
      bedrock_region: "us-east-1"
    )
  end

  it "assembles preface, body, and closing without recommending a rating" do
    llm = instance_double(Llm::Client::Result, content: "Pat shipped demos and got kudos from a peer.")
    allow(Llm::Client).to receive(:call).and_return(llm)

    expect(described_class.call(check_in: check_in, og_consultation: consultation, viewer_person: viewer_person)).to be(true)

    consultation.reload
    expect(consultation.status).to eq("completed")
    text = consultation.result.output_text
    expect(text).to include("OG's brief of")
    expect(text).to include("Assignment Ship weekly demos")
    expect(text).to include("Pat shipped demos and got kudos from a peer.")
    expect(text).to include(CheckIns::PeriodBriefPrompts::CLOSING_LINE)
    expect(text).not_to match(/you should rate/i)
  end
end
