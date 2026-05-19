# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalProject::SyncCacheableJob, type: :job do
  let(:organization) { create(:organization) }
  let(:employee) { create(:company_teammate, organization: organization) }
  let(:link) { create(:one_on_one_link, teammate: employee, url: "https://app.asana.com/0/123/456") }
  let!(:cache) do
    create(
      :external_project_cache,
      cacheable: link,
      source: "asana",
      sync_status: "pending",
      sync_started_at: Time.current,
      last_synced_at: 2.days.ago
    )
  end

  before do
    create(:teammate_identity, :asana, teammate: employee)
    allow(ExternalProject::PerformSync).to receive(:call).and_return(success: true, synced_by_teammate_id: employee.id)
  end

  it "runs PerformSync for the cacheable" do
    described_class.perform_now(link.class.name, link.id, "asana", employee.id)

    expect(ExternalProject::PerformSync).to have_received(:call).with(
      hash_including(
        cacheable: link,
        source: "asana",
        sync_teammates: [employee],
        cache: cache,
        update_ui_status: true
      )
    )
  end

  it "marks the cache failed when PerformSync raises" do
    allow(ExternalProject::PerformSync).to receive(:call).and_raise(StandardError, "boom")

    expect {
      described_class.perform_now(link.class.name, link.id, "asana", employee.id)
    }.not_to raise_error

    expect(cache.reload.sync_status).to eq("failed")
    expect(cache.sync_error).to include("boom")
  end

  it "marks the cache failed when still in progress after PerformSync returns" do
    allow(ExternalProject::PerformSync).to receive(:call).and_return(success: false, errors: [])

    described_class.perform_now(link.class.name, link.id, "asana", employee.id)

    expect(cache.reload.sync_status).to eq("failed")
    expect(cache.sync_error_type).to eq("sync_incomplete")
  end
end
