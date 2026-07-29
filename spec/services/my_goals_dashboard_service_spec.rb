# frozen_string_literal: true

require "rails_helper"

RSpec.describe MyGoalsDashboardService do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.find_or_create_by!(person: person, organization: company) }

  def owned_goal_base
    { owner: teammate, creator: teammate, company: company, goal_type: "quantitative_key_result" }
  end

  def create_goal_item(goal_id:, status:)
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: company,
      level: "item",
      category: EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
      entity_type: "Goal",
      entity_id: goal_id,
      status: status,
      inputs: {},
      computed_at: Time.current
    )
  end

  describe "#counts" do
    it "returns zeros when teammate is nil" do
      expect(described_class.new(teammate: nil).counts).to eq(
        with_recent_check_in: 0,
        without_recent_check_in: 0,
        draft: 0,
        completed: 0
      )
    end

    it "counts draft / unstarted goals owned by teammate" do
      create(:goal, **owned_goal_base, started_at: nil, completed_at: nil, deleted_at: nil)
      create(:goal, **owned_goal_base, started_at: 1.day.ago, completed_at: nil, deleted_at: nil)

      c = described_class.new(teammate: teammate).counts
      expect(c[:draft]).to eq(1)
    end

    it "counts Healthy vs non-Healthy scored goals from EngagementHealth" do
      healthy_goal = create(:goal, **owned_goal_base, started_at: 1.day.ago, completed_at: nil, deleted_at: nil)
      stale_goal = create(:goal, **owned_goal_base, started_at: 1.day.ago, completed_at: nil, deleted_at: nil)
      create_goal_item(goal_id: healthy_goal.id, status: EngagementHealth::HEALTHY)
      create_goal_item(goal_id: stale_goal.id, status: EngagementHealth::WARNING)

      c = described_class.new(teammate: teammate).counts
      expect(c[:with_recent_check_in]).to eq(1)
      expect(c[:without_recent_check_in]).to eq(1)
    end

    it "treats Needs Attention items as without recent check-in" do
      goal = create(:goal, **owned_goal_base, started_at: 1.day.ago, completed_at: nil, deleted_at: nil)
      create_goal_item(goal_id: goal.id, status: EngagementHealth::NEEDS_ATTENTION)

      c = described_class.new(teammate: teammate).counts
      expect(c[:with_recent_check_in]).to eq(0)
      expect(c[:without_recent_check_in]).to eq(1)
    end

    it "counts completed goals owned by teammate" do
      create(
        :goal,
        **owned_goal_base,
        started_at: 1.week.ago,
        completed_at: 1.day.ago,
        deleted_at: nil
      )

      expect(described_class.new(teammate: teammate).counts[:completed]).to eq(1)
    end

    it "does not count goals owned by someone else" do
      other = create(:company_teammate, organization: company)
      create(
        :goal,
        owner: other,
        creator: other,
        company: company,
        goal_type: "quantitative_key_result",
        started_at: 1.day.ago,
        completed_at: nil,
        deleted_at: nil
      )

      expect(described_class.new(teammate: teammate).counts[:without_recent_check_in]).to eq(0)
    end
  end
end
