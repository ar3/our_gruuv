# frozen_string_literal: true

require "rails_helper"

RSpec.describe MilestonesHealthSpotlightService do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  subject(:service) do
    described_class.new(
      organization: organization,
      current_person: person,
      current_company_teammate: teammate,
      manage_employment: true
    )
  end

  def create_milestones_status(status, items: [])
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: organization,
      level: "category",
      category: EngagementHealth::CATEGORY_MILESTONES,
      status: status,
      inputs: {},
      computed_at: Time.current
    )
    items.each do |item|
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: organization,
        level: "item",
        category: EngagementHealth::CATEGORY_MILESTONES,
        entity_type: "Ability",
        entity_id: item[:id],
        status: item[:status],
        inputs: { "name" => item[:name], "reason" => item[:reason] },
        computed_at: Time.current
      )
    end
  end

  describe "#rows_and_spotlight_for" do
    it "uses EngagementHealth Milestones for overall spotlight status" do
      create_milestones_status(
        EngagementHealth::HEALTHY,
        items: [{ id: 1, status: EngagementHealth::HEALTHY, name: "Writing", reason: "earned_required_milestone" }]
      )

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:healthy)
      expect(row[:status_counts][EngagementHealth::HEALTHY]).to eq(1)
      expect(data[:spotlight_stats][:healthy_count]).to eq(1)
    end

    it "lists non-healthy abilities as attention items" do
      create_milestones_status(
        EngagementHealth::NEEDS_ATTENTION,
        items: [
          { id: 10, status: EngagementHealth::NEEDS_ATTENTION, name: "Speaking", reason: "no_milestone_and_no_goal" },
          { id: 11, status: EngagementHealth::HEALTHY, name: "Writing", reason: "earned_required_milestone" }
        ]
      )

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:concerning)
      expect(row[:attention_items].size).to eq(1)
      expect(row[:attention_items].first[:name]).to eq("Speaking")
    end

    it "treats missing EngagementHealth as Needs Attention" do
      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:concerning)
      expect(data[:spotlight_stats][:needs_attention_count]).to eq(1)
    end
  end
end
