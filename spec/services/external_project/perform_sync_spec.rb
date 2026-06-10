# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalProject::PerformSync do
  let(:organization) { create(:organization) }
  let(:employee) { create(:company_teammate, organization: organization) }
  let(:link) { create(:one_on_one_link, teammate: employee, url: "https://app.asana.com/0/123/456") }
  let!(:cache) do
    create(
      :external_project_cache,
      cacheable: link,
      source: "asana",
      sync_status: "pending",
      last_synced_at: 1.day.ago
    )
  end

  before do
    create(:teammate_identity, :asana, teammate: employee)
  end

  it "marks the cache completed when sync succeeds" do
    allow(ExternalProjectCacheService).to receive(:sync_project).and_return(success: true, cache: cache)

    result = described_class.call(
      cacheable: link,
      source: "asana",
      sync_teammates: [employee],
      cache: cache,
      update_ui_status: true
    )

    expect(result[:success]).to be true
    expect(cache.reload.sync_status).to eq("completed")
    expect(cache.sync_error).to be_nil
    expect(cache.sync_error).to be_nil
  end

  it "does not touch cache status when update_ui_status is false" do
    allow(ExternalProjectCacheService).to receive(:sync_project).and_return(success: true, cache: cache)

    result = described_class.call(
      cacheable: link,
      source: "asana",
      sync_teammates: [employee],
      update_ui_status: false
    )

    expect(result[:success]).to be true
    expect(cache.reload.sync_status).to eq("pending")
  end

  it "marks the cache failed with a message when sync fails" do
    allow(ExternalProjectCacheService).to receive(:sync_project).and_return(
      success: false,
      error: "Token expired",
      error_type: "token_expired"
    )

    result = described_class.call(
      cacheable: link,
      source: "asana",
      sync_teammates: [employee],
      cache: cache,
      update_ui_status: true
    )

    expect(result[:success]).to be false
    expect(cache.reload.sync_status).to eq("failed")
    expect(cache.sync_error).to include("token has expired")
    expect(cache.sync_error_type).to eq("token_expired")
  end
end
