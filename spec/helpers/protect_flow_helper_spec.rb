# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProtectFlowHelper, type: :helper do
  describe "#protect_flow_day_label" do
    it "formats a date like Nov 9th" do
      expect(helper.protect_flow_day_label(Date.new(2026, 11, 9))).to eq("Nov 9th")
    end

    it "parses an iso8601 timestamp to the local calendar day" do
      expect(helper.protect_flow_day_label("2026-11-13T15:22:01Z")).to eq("Nov 13th")
    end
  end

  describe "#protect_flow_person_week_summary" do
    it "summarizes warning/unhealthy progress when work remains" do
      summary = helper.protect_flow_person_week_summary(
        start_needs_work_count: 3,
        current_needs_work_count: 2,
        week_needs_work_count: 3,
        improved_count: 1,
        worst_status: EngagementHealth::NEEDS_ATTENTION
      )

      expect(summary).to include("of the 3 warning/unhealthy signals, we've improved 1 so far")
      expect(summary).to include("we can get all of these essential clarity signals steady")
    end

    it "uses on-track keep copy when nothing needed work and nothing is open now" do
      summary = helper.protect_flow_person_week_summary(
        start_needs_work_count: 0,
        current_needs_work_count: 0,
        week_needs_work_count: 0,
        improved_count: 0,
        worst_status: EngagementHealth::HEALTHY
      )

      expect(summary).to include("we're on track")
      expect(summary).to include("we can keep all of these essential clarity signals steady")
      expect(summary).not_to include("of the 0")
    end

    it "does not say on track when current signals need work even if week-start was zero" do
      summary = helper.protect_flow_person_week_summary(
        start_needs_work_count: 0,
        current_needs_work_count: 5,
        week_needs_work_count: 5,
        improved_count: 0,
        worst_status: EngagementHealth::NEEDS_ATTENTION
      )

      expect(summary).not_to include("we're on track")
      expect(summary).to include("of the 5 warning/unhealthy signals, we've improved 0 so far")
      expect(summary).to include("we can get all of these essential clarity signals steady")
    end

    it "falls back to attention_items when counts are missing" do
      summary = helper.protect_flow_person_week_summary(
        start_needs_work_count: 0,
        improved_count: 0,
        attention_items: [
          { category: EngagementHealth::CATEGORY_OGO_GIVEN },
          { category: EngagementHealth::CATEGORY_MILESTONES }
        ],
        worst_status: EngagementHealth::NEEDS_ATTENTION
      )

      expect(summary).not_to include("we're on track")
      expect(summary).to include("of the 2 warning/unhealthy signals")
    end
  end
end
