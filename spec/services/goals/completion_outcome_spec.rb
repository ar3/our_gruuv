# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::CompletionOutcome do
  describe ".from_confidence" do
    it "maps 100 to hit and 0 to miss" do
      expect(described_class.from_confidence(100)).to eq(:hit)
      expect(described_class.from_confidence(0)).to eq(:miss)
      expect(described_class.from_confidence(75)).to be_nil
      expect(described_class.from_confidence(nil)).to be_nil
    end
  end

  describe ".for_goal_ids" do
    let(:company) { create(:organization) }
    let(:teammate) { create(:teammate, organization: company) }

    it "uses the latest check-in confidence per goal" do
      goal = create(:goal, company: company, owner: teammate, creator: teammate, completed_at: Time.current)
      create(
        :goal_check_in,
        goal: goal,
        confidence_percentage: 0,
        check_in_week_start: 2.weeks.ago.beginning_of_week(:monday)
      )
      create(
        :goal_check_in,
        goal: goal,
        confidence_percentage: 100,
        check_in_week_start: 1.week.ago.beginning_of_week(:monday)
      )

      expect(described_class.for_goal_ids([goal.id])).to eq(goal.id => :hit)
    end
  end
end
