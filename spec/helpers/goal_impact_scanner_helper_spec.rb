# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoalImpactScannerHelper, type: :helper do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: company) }

  describe "#goal_impact_designation_pill_text" do
    it "combines initial confidence designation with goal type" do
      goal = build(
        :goal,
        creator: teammate,
        owner: teammate,
        initial_confidence: "commit",
        goal_type: "quantitative_key_result"
      )

      expect(helper.goal_impact_designation_pill_text(goal)).to eq("Commit – Quantitative key result")
    end
  end

  describe "#goal_impact_designation_popover_content" do
    it "explains the framework and this goal's designation" do
      goal = build(:goal, creator: teammate, owner: teammate, initial_confidence: "transform")
      html = helper.goal_impact_designation_popover_content(goal)

      expect(html).to include("Commit")
      expect(html).to include("Stretch")
      expect(html).to include("Transform")
      expect(html).to include("This goal is a Transform goal")
      expect(html).to include("change everything")
    end
  end

  describe "#goal_impact_rollup_summary" do
    it "summarizes descendant count and average latest confidence" do
      bands = Goals::ImpactScannerQuery::BandCounts.new(high: 2, mid: 1, low: 0, no_check_in: 1)
      rollup = Goals::ImpactScannerQuery::Rollup.new(
        bands: bands,
        average_confidence: 70.0,
        descendant_count: 4,
        checked_in_count: 3
      )

      expect(helper.goal_impact_rollup_summary(rollup))
        .to eq("4 descendant goals, and their latest confidence, averages 70.0%")
    end

    it "uses singular wording for one descendant" do
      bands = Goals::ImpactScannerQuery::BandCounts.new(high: 1, mid: 0, low: 0, no_check_in: 0)
      rollup = Goals::ImpactScannerQuery::Rollup.new(
        bands: bands,
        average_confidence: 90.0,
        descendant_count: 1,
        checked_in_count: 1
      )

      expect(helper.goal_impact_rollup_summary(rollup))
        .to eq("1 descendant goal, and its latest confidence, averages 90.0%")
    end

    it "notes when descendants have no latest confidence" do
      bands = Goals::ImpactScannerQuery::BandCounts.new(high: 0, mid: 0, low: 0, no_check_in: 2)
      rollup = Goals::ImpactScannerQuery::Rollup.new(
        bands: bands,
        average_confidence: nil,
        descendant_count: 2,
        checked_in_count: 0
      )

      expect(helper.goal_impact_rollup_summary(rollup))
        .to eq("2 descendant goals; none have a latest confidence check yet")
    end

    it "returns nil when there are no descendants" do
      bands = Goals::ImpactScannerQuery::BandCounts.new(high: 0, mid: 0, low: 0, no_check_in: 0)
      rollup = Goals::ImpactScannerQuery::Rollup.new(
        bands: bands,
        average_confidence: nil,
        descendant_count: 0,
        checked_in_count: 0
      )

      expect(helper.goal_impact_rollup_summary(rollup)).to be_nil
    end
  end
end
