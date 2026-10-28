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

  describe ".due_on_for" do
    it "is last finalize + needs-attention days (end of warning)" do
      last = Date.new(2026, 1, 15)
      item = EngagementHealthStatus.new(
        inputs: { "last_event_at" => last.iso8601, "never" => false }
      )

      expect(described_class.due_on_for(item)).to eq(
        last + EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS
      )
    end

    it "falls back to tenure start + needs-attention days when never finalized" do
      tenure_start = Date.new(2026, 2, 1)
      item = EngagementHealthStatus.new(
        inputs: {
          "never" => true,
          "tenure_chain_started_at" => tenure_start.iso8601
        }
      )

      expect(described_class.due_on_for(item)).to eq(
        tenure_start + EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS
      )
    end

    it "uses the day after grace_until when in Grey Grace even if finalize-based needs-attention is past" do
      grace_until = Date.current + 14.days
      item = EngagementHealthStatus.new(
        status: EngagementHealth::WARNING,
        inputs: {
          "never" => false,
          "last_event_at" => 100.days.ago.iso8601,
          "needs_attention_at" => (Date.current - 10.days).iso8601,
          "grace_until_at" => grace_until.iso8601,
          "clarity_check_in_grace" => true
        }
      )

      expect(described_class.due_on_for(item)).to eq(grace_until + 1.day)
    end

    it "prefers cached needs_attention_at when not in grace" do
      needs = Date.new(2026, 6, 1)
      item = EngagementHealthStatus.new(
        inputs: {
          "last_event_at" => Date.new(2026, 1, 1).iso8601,
          "needs_attention_at" => needs.iso8601,
          "clarity_check_in_grace" => false
        }
      )

      expect(described_class.due_on_for(item)).to eq(needs)
    end

    it "has no due date during indefinite assignment Grey Grace" do
      item = EngagementHealthStatus.new(
        status: EngagementHealth::WARNING,
        inputs: {
          "never" => true,
          "clarity_check_in_grace" => true,
          "indefinite_assignment_grace" => true
        }
      )

      expect(described_class.due_on_for(item)).to be_nil
    end
  end



  describe ".earliest_due_item" do
    it "picks the required item with the earliest due date" do
      earlier = EngagementHealthStatus.create!(
        teammate: teammate,
        organization: organization,
        level: "item",
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        entity_type: "Assignment",
        entity_id: 10,
        status: EngagementHealth::HEALTHY,
        inputs: {
          "name" => "Earlier Due",
          "last_event_at" => 100.days.ago.iso8601,
          "never" => false
        },
        computed_at: Time.current
      )
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: organization,
        level: "item",
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        entity_type: "Assignment",
        entity_id: 11,
        status: EngagementHealth::HEALTHY,
        inputs: {
          "name" => "Later Due",
          "last_event_at" => 10.days.ago.iso8601,
          "never" => false
        },
        computed_at: Time.current
      )

      expect(described_class.earliest_due_item(EngagementHealthStatus.where(teammate: teammate))).to eq(earlier)
    end

    it "prefers never-finalized items with no due date over dated items" do
      never_item = EngagementHealthStatus.create!(
        teammate: teammate,
        organization: organization,
        level: "item",
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        entity_type: "Position",
        entity_id: 1,
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: { "name" => "Seat", "never" => true },
        computed_at: Time.current
      )
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: organization,
        level: "item",
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        entity_type: "Assignment",
        entity_id: 2,
        status: EngagementHealth::WARNING,
        inputs: {
          "name" => "Craft",
          "last_event_at" => 80.days.ago.iso8601,
          "never" => false
        },
        computed_at: Time.current
      )

      expect(described_class.earliest_due_item(EngagementHealthStatus.where(teammate: teammate))).to eq(never_item)
    end
  end
end
