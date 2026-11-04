# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::StartPeriodBriefConsult do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:triggered) { create(:teammate, person: person, organization: organization) }
  let(:employee) { create(:teammate, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:check_in) do
    create(
      :assignment_check_in,
      teammate: employee,
      assignment: assignment,
      check_in_started_on: Date.current,
      official_check_in_completed_at: nil
    )
  end

  it "creates a pending billable consultation and enqueues the job" do
    expect do
      result = described_class.call(
        organization: organization,
        triggered_by_teammate: triggered,
        check_in: check_in
      )
      expect(result).to be_ok
      expect(result.consultation.kind).to eq(OgConsultation::KIND_CHECK_IN_PERIOD_BRIEF)
      expect(result.consultation.billable).to be(true)
      expect(result.consultation.prompt_version).to eq(CheckIns::PeriodBriefPrompts::PROMPT_VERSION)
    end.to have_enqueued_job(CheckInPeriodBriefJob)
  end

  it "reuses an in-flight consultation for the same viewer" do
    inflight = create_check_in_period_brief_consultation!(
      check_in: check_in,
      status: "processing",
      triggered_by_teammate: triggered
    )

    expect do
      result = described_class.call(
        organization: organization,
        triggered_by_teammate: triggered,
        check_in: check_in
      )
      expect(result).to be_ok
      expect(result.consultation).to eq(inflight)
    end.not_to have_enqueued_job(CheckInPeriodBriefJob)
  end

  it "starts a separate consultation for a different viewer" do
    other_viewer = create(:teammate, organization: organization)
    create_check_in_period_brief_consultation!(
      check_in: check_in,
      status: "completed",
      triggered_by_teammate: other_viewer,
      output_text: "Other viewer's brief"
    )

    expect do
      result = described_class.call(
        organization: organization,
        triggered_by_teammate: triggered,
        check_in: check_in
      )
      expect(result).to be_ok
      expect(result.consultation.triggered_by_teammate).to eq(triggered)
      expect(result.consultation.id).not_to eq(check_in.latest_period_brief_consultation_for(other_viewer).id)
    end.to have_enqueued_job(CheckInPeriodBriefJob)
  end
end
