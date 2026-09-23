# frozen_string_literal: true

require "rails_helper"

RSpec.describe JobDescriptionAcknowledgements::ComplianceStatus do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization, first_employed_at: 1.year.ago) }
  let!(:tenure) do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 60.days.ago, ended_at: nil)
  end

  it "is not compliant when there is no signature after the latest trigger" do
    result = described_class.call(teammate: teammate, organization: organization, acknowledgements: [])

    expect(result.compliant?).to eq(false)
    expect(result.latest_trigger_at).to be_within(1.second).of(tenure.started_at)
  end

  it "is compliant when a signature comes after the latest position change or finalized check-in" do
    create(
      :position_check_in,
      :closed,
      teammate: teammate,
      employment_tenure: tenure,
      official_check_in_completed_at: 10.days.ago
    )
    acknowledgement = JobDescriptionAcknowledgement.new(
      company_teammate: teammate,
      organization: organization,
      typed_name: teammate.person.government_first_then_last_display_name,
      signed_at: 5.days.ago,
      document_html: "<p>signed</p>",
      snapshot: { "position_name" => "Role" }
    )
    acknowledgement.save!(validate: false)

    result = described_class.call(
      teammate: teammate,
      organization: organization,
      acknowledgements: [acknowledgement]
    )

    expect(result.compliant?).to eq(true)
    expect(result.latest_trigger_at).to be_within(1.second).of(10.days.ago)
  end
end
