# frozen_string_literal: true

require "rails_helper"

RSpec.describe EngagementHealth, ".refresh_now_or_schedule_for" do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: organization) }

  it "refreshes synchronously and does not enqueue a job" do
    expect(EngagementHealth::Refresher).to receive(:call).with(
      an_object_having_attributes(id: teammate.id)
    ).and_call_original

    expect {
      described_class.refresh_now_or_schedule_for(teammate.id)
    }.not_to have_enqueued_job(EngagementHealthRefreshJob)

    expect(EngagementHealthStatus.where(teammate: teammate, organization: organization)).to exist
  end

  it "schedules async refresh when sync refresh raises" do
    allow(EngagementHealth::Refresher).to receive(:call).and_raise(StandardError, "boom")

    expect {
      described_class.refresh_now_or_schedule_for(teammate.id)
    }.to have_enqueued_job(EngagementHealthRefreshJob).with(teammate.id)
  end

  it "no-ops for a blank teammate id" do
    expect(EngagementHealth::Refresher).not_to receive(:call)

    expect {
      described_class.refresh_now_or_schedule_for(nil)
    }.not_to have_enqueued_job(EngagementHealthRefreshJob)
  end

  it "schedules async refresh when the teammate is missing" do
    expect(EngagementHealth::Refresher).not_to receive(:call)

    expect {
      described_class.refresh_now_or_schedule_for(-1)
    }.to have_enqueued_job(EngagementHealthRefreshJob).with(-1)
  end
end
