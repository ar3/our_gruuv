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
        inputs: {
          "name" => item[:name],
          "reason" => item[:reason],
          "required_level" => item[:required_level] || 1
        },
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

    it "lists a single non-healthy ability as the attention item" do
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

    it "prefers the ability with more required assignments, then higher required milestone, then Needs Attention name" do
      speaking_id = 101
      writing_id = 102
      alpha_id = 103

      create_milestones_status(
        EngagementHealth::NEEDS_ATTENTION,
        items: [
          { id: speaking_id, status: EngagementHealth::WARNING, name: "Speaking", reason: "earlier_milestone_earned", required_level: 3 },
          { id: writing_id, status: EngagementHealth::NEEDS_ATTENTION, name: "Writing", reason: "no_milestone_and_no_goal", required_level: 2 },
          { id: alpha_id, status: EngagementHealth::NEEDS_ATTENTION, name: "Alpha Craft", reason: "no_milestone_and_no_goal", required_level: 3 }
        ]
      )

      allow(service).to receive(:required_assignment_counts_by_teammate).and_return(
        { teammate.id => { writing_id => 2, speaking_id => 1, alpha_id => 1 } }
      )

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      # Writing is on 2 required assignments; Speaking/Alpha only on 1.
      expect(row[:attention_items].map { |i| i[:name] }).to eq(["Writing"])
    end

    it "when assignment counts tie, prefers higher required milestone then Needs Attention alphanumeric" do
      create_milestones_status(
        EngagementHealth::NEEDS_ATTENTION,
        items: [
          { id: 201, status: EngagementHealth::WARNING, name: "Zebra", reason: "earlier_milestone_earned", required_level: 4 },
          { id: 202, status: EngagementHealth::NEEDS_ATTENTION, name: "Beta", reason: "no_milestone_and_no_goal", required_level: 4 },
          { id: 203, status: EngagementHealth::NEEDS_ATTENTION, name: "Alpha", reason: "no_milestone_and_no_goal", required_level: 4 }
        ]
      )

      allow(service).to receive(:required_assignment_counts_by_teammate).and_return(
        { teammate.id => { 201 => 1, 202 => 1, 203 => 1 } }
      )

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:attention_items].map { |i| i[:name] }).to eq(["Alpha"])
    end

    it "treats missing EngagementHealth as Needs Attention" do
      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:concerning)
      expect(data[:spotlight_stats][:needs_attention_count]).to eq(1)
    end
  end
end
