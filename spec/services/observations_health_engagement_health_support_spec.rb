# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObservationsHealthEngagementHealthSupport do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }

  def create_category_status(category, status, inputs: {})
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: organization,
      level: "category",
      category: category,
      status: status,
      inputs: inputs,
      computed_at: Time.current
    )
  end

  describe ".overall_status" do
    it "returns the worse of Given and Received" do
      records = [
        create_category_status(EngagementHealth::CATEGORY_OGO_GIVEN, EngagementHealth::HEALTHY),
        create_category_status(EngagementHealth::CATEGORY_OGO_RECEIVED, EngagementHealth::WARNING)
      ]

      expect(described_class.overall_status(records)).to eq(EngagementHealth::WARNING)
    end

    it "treats missing category rollups as Needs Attention" do
      expect(described_class.overall_status([])).to eq(EngagementHealth::NEEDS_ATTENTION)
    end
  end

  describe ".section_payload" do
    it "builds a Given/Received cell hash from the category rollup inputs" do
      records = [
        create_category_status(
          EngagementHealth::CATEGORY_OGO_GIVEN,
          EngagementHealth::HEALTHY,
          inputs: { "last_event_at" => 2.days.ago.iso8601, "never" => false }
        )
      ]

      payload = described_class.section_payload(
        records,
        category: EngagementHealth::CATEGORY_OGO_GIVEN,
        observations_count: 3
      )

      expect(payload["status"]).to eq(EngagementHealth::HEALTHY)
      expect(payload["observations_count"]).to eq(3)
      expect(payload["last_published_at"]).to be_present
      expect(payload["never"]).to eq(false)
    end

    it "defaults missing rollups to Needs Attention" do
      payload = described_class.section_payload(
        [],
        category: EngagementHealth::CATEGORY_OGO_RECEIVED,
        observations_count: 0
      )

      expect(payload["status"]).to eq(EngagementHealth::NEEDS_ATTENTION)
      expect(payload["never"]).to eq(true)
    end
  end
end
