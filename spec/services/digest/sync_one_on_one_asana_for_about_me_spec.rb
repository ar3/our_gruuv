# frozen_string_literal: true

require "rails_helper"

RSpec.describe Digest::SyncOneOnOneAsanaForAboutMe do
  let(:organization) { create(:organization) }
  let(:employee) { create(:company_teammate, organization: organization) }
  let(:manager) { create(:company_teammate, organization: organization) }

  describe ".call" do
    it "skips when there is no 1:1 link" do
      expect(ExternalProjectCacheService).not_to receive(:sync_project)

      result = described_class.call(employee_teammate: employee, manager_teammate: manager)

      expect(result).to eq(synced: false, skipped: :no_link)
    end

    it "skips when the link is not Asana" do
      create(:one_on_one_link, teammate: employee, url: "https://docs.google.com/document/d/abc/edit")

      expect(ExternalProjectCacheService).not_to receive(:sync_project)

      result = described_class.call(employee_teammate: employee, manager_teammate: manager)

      expect(result).to eq(synced: false, skipped: :not_asana)
    end

    it "skips when Asana has never been synced successfully" do
      link = create(:one_on_one_link, teammate: employee, url: "https://app.asana.com/0/123/456")

      expect(ExternalProjectCacheService).not_to receive(:sync_project)

      result = described_class.call(employee_teammate: employee, manager_teammate: manager)

      expect(result).to eq(synced: false, skipped: :never_synced)
      expect(link.external_project_cache_for("asana")).to be_nil
    end

    it "tries the employee first, then the manager" do
      link = create(:one_on_one_link, teammate: employee, url: "https://app.asana.com/0/123/456")
      create(:external_project_cache, cacheable: link, source: "asana", last_synced_at: 2.days.ago)

      expect(ExternalProject::PerformSync).to receive(:call).with(
        cacheable: link,
        source: "asana",
        sync_teammates: [employee, manager],
        update_ui_status: false
      ).and_return(success: true, synced_by_teammate_id: manager.id)

      result = described_class.call(employee_teammate: employee, manager_teammate: manager)

      expect(result).to eq(synced: true, synced_by_teammate_id: manager.id)
    end

    it "returns synced when the employee sync succeeds" do
      link = create(:one_on_one_link, teammate: employee, url: "https://app.asana.com/0/123/456")
      cache = create(:external_project_cache, cacheable: link, source: "asana", last_synced_at: 1.day.ago)

      expect(ExternalProject::PerformSync).to receive(:call).with(
        cacheable: link,
        source: "asana",
        sync_teammates: [employee, manager],
        update_ui_status: false
      ).and_return(success: true, synced_by_teammate_id: employee.id)

      result = described_class.call(employee_teammate: employee, manager_teammate: manager)

      expect(result).to eq(synced: true, synced_by_teammate_id: employee.id)
    end

    it "returns failure details when all sync attempts fail" do
      link = create(:one_on_one_link, teammate: employee, url: "https://app.asana.com/0/123/456")
      create(:external_project_cache, cacheable: link, source: "asana", last_synced_at: 1.day.ago)

      expect(ExternalProject::PerformSync).to receive(:call).and_return(
        success: false,
        errors: [
          { teammate_id: employee.id, error: "Token expired", error_type: "token_expired" },
          { teammate_id: manager.id, error: "Token expired", error_type: "token_expired" }
        ]
      )

      result = described_class.call(employee_teammate: employee, manager_teammate: manager)

      expect(result[:synced]).to be false
      expect(result[:errors].size).to eq(2)
    end
  end
end
