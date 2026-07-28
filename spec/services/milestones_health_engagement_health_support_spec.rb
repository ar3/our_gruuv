# frozen_string_literal: true

require "rails_helper"

RSpec.describe MilestonesHealthEngagementHealthSupport do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }

  def create_status(level:, status:, entity_id: nil, inputs: {})
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: organization,
      level: level,
      category: EngagementHealth::CATEGORY_MILESTONES,
      entity_type: (level == "item" ? "Ability" : nil),
      entity_id: entity_id,
      status: status,
      inputs: inputs,
      computed_at: Time.current
    )
  end

  describe ".category_status" do
    it "returns the category rollup status" do
      create_status(level: "category", status: EngagementHealth::WARNING)
      records = described_class.records_by_teammate_id(organization: organization, teammate_ids: [teammate.id])[teammate.id]
      expect(described_class.category_status(records)).to eq(EngagementHealth::WARNING)
    end

    it "defaults to Needs Attention when missing" do
      expect(described_class.category_status([])).to eq(EngagementHealth::NEEDS_ATTENTION)
    end
  end

  describe ".status_counts" do
    it "counts ability items by status" do
      items = [
        create_status(level: "item", status: EngagementHealth::HEALTHY, entity_id: 1),
        create_status(level: "item", status: EngagementHealth::WARNING, entity_id: 2),
        create_status(level: "item", status: EngagementHealth::NEEDS_ATTENTION, entity_id: 3)
      ]
      expect(described_class.status_counts(items)).to eq(
        EngagementHealth::HEALTHY => 1,
        EngagementHealth::WARNING => 1,
        EngagementHealth::NEEDS_ATTENTION => 1
      )
    end
  end
end
