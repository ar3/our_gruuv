# frozen_string_literal: true

require "rails_helper"

RSpec.describe EngagementHealth::GoalConfidence do
  let(:company) { create(:organization, :company) }
  let(:creator) { create(:teammate, organization: company) }
  let(:team) { create(:team, company: company) }
  let(:reference_time) { Time.zone.parse("2026-06-15 12:00:00") }

  def create_team_goal(**attrs)
    create(
      :goal,
      :with_team_owner,
      owner: team,
      creator: creator,
      company: company,
      title: attrs[:title] || "Team goal",
      started_at: attrs.fetch(:started_at, reference_time - 10.days),
      completed_at: attrs[:completed_at],
      created_at: attrs.fetch(:created_at, reference_time - 20.days)
    )
  end

  describe ".rollup_status_for_owner" do
    it "returns Needs Attention when the team has no scored goals" do
      create_team_goal(started_at: nil) # draft only

      result = described_class.rollup_status_for_owner(
        owner_type: "Team",
        owner_id: team.id,
        reference_time: reference_time
      )

      expect(result[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      expect(result[:empty_reason]).to eq("never_started_or_completed_a_goal")
    end

    it "uses best-status-wins across Team-owned scored goals" do
      fresh = create_team_goal(title: "Fresh")
      create(
        :goal_check_in,
        goal: fresh,
        confidence_reporter: creator.person,
        updated_at: reference_time - 5.days
      )
      stale = create_team_goal(title: "Stale")
      create(
        :goal_check_in,
        goal: stale,
        confidence_reporter: creator.person,
        updated_at: reference_time - 100.days
      )

      result = described_class.rollup_status_for_owner(
        owner_type: "Team",
        owner_id: team.id,
        reference_time: reference_time
      )

      expect(result[:status]).to eq(EngagementHealth::HEALTHY)
      expect(result[:empty_reason]).to be_nil
    end
  end
end
