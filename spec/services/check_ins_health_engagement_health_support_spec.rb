# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckInsHealthEngagementHealthSupport do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }

  describe ".clarity_rollup_status" do
    it "returns the required clarity category rollup status" do
      record = EngagementHealthStatus.create!(
        teammate: teammate,
        organization: organization,
        level: "category",
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        status: EngagementHealth::HEALTHY,
        inputs: {},
        computed_at: Time.current
      )

      expect(described_class.clarity_rollup_status([record])).to eq(EngagementHealth::HEALTHY)
    end
  end

  describe ".worst_item" do
    it "returns the item with the worst status" do
      records = [
        EngagementHealthStatus.create!(
          teammate: teammate,
          organization: organization,
          level: "item",
          category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          entity_type: "Assignment",
          entity_id: 1,
          status: EngagementHealth::WARNING,
          inputs: { "name" => "Alpha" },
          computed_at: Time.current
        ),
        EngagementHealthStatus.create!(
          teammate: teammate,
          organization: organization,
          level: "item",
          category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          entity_type: "Aspiration",
          entity_id: 2,
          status: EngagementHealth::NEEDS_ATTENTION,
          inputs: { "name" => "Beta" },
          computed_at: Time.current
        )
      ]

      expect(described_class.worst_item(records).inputs["name"]).to eq("Beta")
    end
  end
end
