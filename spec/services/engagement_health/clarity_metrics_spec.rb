# frozen_string_literal: true

require "rails_helper"

RSpec.describe EngagementHealth::ClarityMetrics do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: organization) }

  def clarity_item(entity_type, entity_id, name, status, inputs = {})
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: organization,
      level: "item",
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      entity_type: entity_type,
      entity_id: entity_id,
      status: status,
      inputs: { "name" => name }.merge(inputs),
      computed_at: Time.current
    )
  end

  describe ".breakdown" do
    it "returns healthy percentages by section" do
      clarity_item("Position", 1, "Engineer", EngagementHealth::HEALTHY)
      clarity_item("Assignment", 2, "Support", EngagementHealth::AT_RISK)
      clarity_item("Aspiration", 3, "Growth", EngagementHealth::HEALTHY)
      records = described_class.records_for_teammate(organization: organization, teammate_id: teammate.id)

      breakdown = described_class.breakdown(records)

      expect(breakdown[:completion_rate]).to eq(66.7)
      expect(breakdown[:position_pct]).to eq(100)
      expect(breakdown[:assignments_pct]).to eq(0)
      expect(breakdown[:aspirations_pct]).to eq(100)
    end
  end

  describe ".fully_clear?" do
    it "is true when every required item is healthy" do
      clarity_item("Position", 1, "Engineer", EngagementHealth::HEALTHY)
      records = described_class.records_for_teammate(organization: organization, teammate_id: teammate.id)

      expect(described_class.fully_clear?(records)).to be(true)
    end
  end
end
