# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoalsHealthEngagementHealthSupport do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }

  def create_status(level:, status:, entity_id: nil, inputs: {})
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: organization,
      level: level,
      category: EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
      entity_type: (level == "item" ? "Goal" : nil),
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

    it "defaults to Needs Attention when missing (including zero-goal people)" do
      expect(described_class.category_status([])).to eq(EngagementHealth::NEEDS_ATTENTION)
    end

    it "preserves Needs Attention when the rollup has never_started_or_completed_a_goal" do
      create_status(
        level: "category",
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: { "empty_reason" => "never_started_or_completed_a_goal" }
      )
      records = described_class.records_by_teammate_id(organization: organization, teammate_ids: [teammate.id])[teammate.id]
      expect(described_class.category_status(records)).to eq(EngagementHealth::NEEDS_ATTENTION)
    end
  end

  describe ".spotlight_symbol" do
    it "maps Warning to :ok for compact spotlight buckets" do
      expect(described_class.spotlight_symbol(EngagementHealth::HEALTHY)).to eq(:healthy)
      expect(described_class.spotlight_symbol(EngagementHealth::WARNING)).to eq(:ok)
      expect(described_class.spotlight_symbol(EngagementHealth::NEEDS_ATTENTION)).to eq(:concerning)
    end
  end
end
