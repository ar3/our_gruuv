# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::SlackOgoConsult::Starter do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:viewer) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }

  before { create(:teammate_identity, :slack_search, teammate: viewer) }

  it "creates a 90-day search with auto-extract and enqueues the search job" do
    expect {
      result = described_class.call(
        organization: organization,
        viewer: viewer,
        subject_teammate: subject_teammate,
        mode: "fresh"
      )
      expect(result.ok?).to eq(true)
      expect(result.search.window_days).to eq(90)
      expect(result.search.auto_extract_after_search).to eq(true)
    }.to change(PossibleObservationSlackSearch, :count).by(1)
      .and have_enqueued_job(PossibleObservationSlackSearchJob)
  end

  it "re-runs extraction on all batches" do
    search = create(
      :possible_observation_slack_search,
      :completed,
      organization: organization,
      creator_company_teammate: viewer,
      subject_company_teammate: subject_teammate
    )

    expect {
      result = described_class.call(
        organization: organization,
        viewer: viewer,
        subject_teammate: subject_teammate,
        mode: "rerun_consultation",
        existing_search: search
      )
      expect(result.ok?).to eq(true)
    }.to have_enqueued_job(PossibleObservationSlackSearchExtractionJob)

    expect(search.message_batches.reload.map(&:extraction_status).uniq).to eq(["pending"])
  end

  it "asks for Slack OAuth when the viewer is not connected" do
    other = create(:company_teammate, :assigned_employee, organization: organization)
    result = described_class.call(
      organization: organization,
      viewer: other,
      subject_teammate: subject_teammate,
      mode: "fresh"
    )
    expect(result.ok?).to eq(false)
    expect(result.needs_slack_oauth).to eq(true)
  end
end
