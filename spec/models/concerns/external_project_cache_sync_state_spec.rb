# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalProjectCacheSyncState do
  let(:organization) { create(:organization) }
  let(:employee) { create(:company_teammate, organization: organization) }
  let(:link) { create(:one_on_one_link, teammate: employee) }
  let(:cache) do
    create(
      :external_project_cache,
      cacheable: link,
      source: "asana",
      sync_status: "processing",
      sync_started_at: 4.minutes.ago
    )
  end

  describe "#reconcile_stale_sync!" do
    it "marks long-running syncs as failed" do
      cache.reconcile_stale_sync!

      expect(cache.reload.sync_status).to eq("failed")
      expect(cache.sync_error_type).to eq("sync_timeout")
    end

    it "does not change a recently started sync" do
      cache.update!(sync_started_at: 1.minute.ago)

      cache.reconcile_stale_sync!

      expect(cache.reload.sync_status).to eq("processing")
    end
  end
end
