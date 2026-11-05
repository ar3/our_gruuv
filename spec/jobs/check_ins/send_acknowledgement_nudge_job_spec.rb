# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::SendAcknowledgementNudgeJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:employee_teammate) { create(:company_teammate, organization: organization) }
  let(:nudger_teammate) { create(:company_teammate, organization: organization) }

  it "sends the acknowledgement nudge for the finalizer and teammate" do
    expect(CheckIns::AcknowledgementNudgeService).to receive(:call).with(
      organization: organization,
      employee_teammate: employee_teammate,
      nudger_company_teammate: nudger_teammate
    ).and_return(Result.ok(notification: nil))

    described_class.perform_now(
      organization_id: organization.id,
      employee_teammate_id: employee_teammate.id,
      nudger_company_teammate_id: nudger_teammate.id
    )
  end

  it "finishes quietly when the nudge cannot be sent" do
    allow(CheckIns::AcknowledgementNudgeService).to receive(:call)
      .and_return(Result.err("Both you and the teammate must have Slack connected to send a nudge."))

    expect {
      described_class.perform_now(
        organization_id: organization.id,
        employee_teammate_id: employee_teammate.id,
        nudger_company_teammate_id: nudger_teammate.id
      )
    }.not_to raise_error
  end
end
