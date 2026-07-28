# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoalsHealthSpotlightService do
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

  def create_goal_confidence(status)
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: organization,
      level: "category",
      category: EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
      status: status,
      inputs: {},
      computed_at: Time.current
    )
  end

  describe "#rows_and_spotlight_for" do
    it "uses EngagementHealth Goal Confidence for overall spotlight status" do
      create_goal_confidence(EngagementHealth::HEALTHY)

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:healthy)
      expect(data[:spotlight_stats][:healthy_count]).to eq(1)
      expect(data[:spotlight_stats][:warning_count]).to eq(0)
    end

    it "maps Warning to the ok spotlight bucket and defaults missing EH to Needs Attention" do
      create_goal_confidence(EngagementHealth::WARNING)

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:ok)
      expect(data[:spotlight_stats][:warning_count]).to eq(1)
      expect(data[:spotlight_stats][:ok_count]).to eq(1)
    end

    it "treats missing EngagementHealth as Needs Attention" do
      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:concerning)
      expect(row[:status_lines][EngagementHealth::HEALTHY]).to eq(active: 0, completed: 0, draft: 0)
      expect(data[:spotlight_stats][:needs_attention_count]).to eq(1)
    end

    it "exposes status lines and attachment summary without bucket columns" do
      create_goal_confidence(EngagementHealth::NEEDS_ATTENTION)
      create(:goal, owner: teammate, company: organization, started_at: nil, completed_at: nil, title: "Draft only")

      data = service.rows_and_spotlight_for("just_me")
      row = data[:rows].find { |r| r[:teammate].id == teammate.id }

      expect(row[:status]).to eq(:concerning)
      expect(row[:status_lines][EngagementHealth::NEEDS_ATTENTION][:draft]).to eq(1)
      expect(row[:attachments].active_with_attachments_count).to eq(0)
      expect(row[:attachments].active_child_count).to eq(0)
      expect(row).not_to have_key(:associated)
      expect(row).not_to have_key(:goal_counts)
    end
  end

  describe "#compact_spotlight_stats" do
    it "aliases Warning and Needs Attention into ok_count / concerning_count" do
      create_goal_confidence(EngagementHealth::WARNING)

      stats = service.compact_spotlight_stats("just_me")
      expect(stats[:ok_count]).to eq(1)
      expect(stats[:concerning_count]).to eq(0)
      expect(stats[:healthy_count]).to eq(0)
    end
  end
end
