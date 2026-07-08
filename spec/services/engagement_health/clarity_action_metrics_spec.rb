# frozen_string_literal: true

require "rails_helper"

RSpec.describe EngagementHealth::ClarityActionMetrics do
  def item(status:, inputs: {})
    instance_double(
      EngagementHealthStatus,
      status: status,
      inputs: inputs.stringify_keys
    )
  end

  describe ".slot_counts_for_item" do
    it "counts all 3 slots as healthy for healthy items" do
      counts = described_class.slot_counts_for_item(item(status: EngagementHealth::HEALTHY))

      expect(counts).to eq(healthy_slots: 3, warning_slots: 0, needs_attention_slots: 0)
    end

    it "splits completed and incomplete slots for warning items with an open check-in" do
      warning_item = item(
        status: EngagementHealth::WARNING,
        inputs: {
          "open_check_in_present" => true,
          "open_employee_completed" => true,
          "open_manager_completed" => false
        }
      )

      expect(described_class.slot_counts_for_item(warning_item)).to eq(
        healthy_slots: 1,
        warning_slots: 2,
        needs_attention_slots: 0
      )
    end

    it "puts incomplete slots in needs attention for needs attention items" do
      needs_attention_item = item(status: EngagementHealth::NEEDS_ATTENTION, inputs: { "open_check_in_present" => false })

      expect(described_class.slot_counts_for_item(needs_attention_item)).to eq(
        healthy_slots: 0,
        warning_slots: 0,
        needs_attention_slots: 3
      )
    end
  end

  describe ".breakdown_for_items" do
    it "returns percentages that sum to 100" do
      items = [
        item(status: EngagementHealth::HEALTHY),
        item(
          status: EngagementHealth::NEEDS_ATTENTION,
          inputs: {
            "open_check_in_present" => true,
            "open_employee_completed" => true,
            "open_manager_completed" => false
          }
        )
      ]

      breakdown = described_class.breakdown_for_items(items)

      expect(breakdown.total_slots).to eq(6)
      expect(breakdown.healthy_slots).to eq(4)
      expect(breakdown.needs_attention_slots).to eq(2)
      expect(breakdown.healthy_percentage + breakdown.warning_percentage + breakdown.needs_attention_percentage).to eq(100.0)
      expect(breakdown.ok_percentage).to eq(breakdown.healthy_percentage + breakdown.warning_percentage)
    end
  end

  describe ".popover_rows" do
    it "includes only warning and needs attention items" do
      records = [
        EngagementHealthStatus.new(
          level: "item",
          category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          entity_type: "Aspiration",
          entity_id: 1,
          status: EngagementHealth::HEALTHY,
          inputs: { "name" => "Healthy" }
        ),
        EngagementHealthStatus.new(
          level: "item",
          category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          entity_type: "Assignment",
          entity_id: 2,
          status: EngagementHealth::WARNING,
          inputs: {
            "name" => "Warn",
            "open_check_in_present" => true,
            "open_employee_completed" => true,
            "open_manager_completed" => false
          }
        )
      ]

      rows = described_class.popover_rows(records)

      expect(rows.size).to eq(1)
      expect(rows.first.name).to eq("Warn")
      expect(rows.first.employee_done).to be(true)
      expect(rows.first.manager_done).to be(false)
    end
  end

  describe ".spotlight_stats" do
    let(:organization) { create(:organization) }
    let(:teammate) { create(:company_teammate, organization: organization) }

    it "aggregates action slots across teammates" do
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: organization,
        level: "item",
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        entity_type: "Aspiration",
        entity_id: 1,
        status: EngagementHealth::HEALTHY,
        inputs: { "name" => "Growth" },
        computed_at: Time.current
      )
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: organization,
        level: "item",
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        entity_type: "Assignment",
        entity_id: 2,
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: {
          "name" => "Support",
          "open_check_in_present" => true,
          "open_employee_completed" => true,
          "open_manager_completed" => false
        },
        computed_at: Time.current
      )

      stats = described_class.spotlight_stats(organization: organization, teammate_ids: [teammate.id])

      expect(stats.total_action_slots).to eq(6)
      expect(stats.healthy_action_slots).to eq(4)
      expect(stats.needs_attention_actions_taken).to eq(1)
      expect(stats.actions_to_full_maap).to eq(2)
    end
  end
end
