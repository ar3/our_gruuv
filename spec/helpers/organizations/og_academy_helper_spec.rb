# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organizations::OgAcademyHelper, type: :helper do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }

  def create_goal_item(status:, goal_state:, entity_id:)
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: organization,
      level: "item",
      category: EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
      entity_type: "Goal",
      entity_id: entity_id,
      status: status,
      inputs: { "goal_state" => goal_state, "name" => "Goal #{entity_id}" },
      computed_at: Time.current
    )
  end

  describe "#og_academy_goals_caption_counts" do
    it "splits active, healthy-active, and recently completed from EH items" do
      create_goal_item(status: EngagementHealth::HEALTHY, goal_state: "active", entity_id: 1)
      create_goal_item(status: EngagementHealth::WARNING, goal_state: "active", entity_id: 2)
      create_goal_item(status: EngagementHealth::HEALTHY, goal_state: "completed", entity_id: 3)
      records = GoalsHealthEngagementHealthSupport.records_by_teammate_id(
        organization: organization,
        teammate_ids: [teammate.id]
      )[teammate.id]

      expect(helper.og_academy_goals_caption_counts(records)).to eq(
        active: 2,
        healthy_active: 1,
        completed_recent: 1
      )
    end
  end

  describe "#og_academy_goals_caption" do
    it "uses the shorter form when there are no active goals" do
      html = helper.og_academy_goals_caption(active: 0, healthy_active: 0, completed_recent: 2)

      expect(html).to include("<strong>0</strong> active.")
      expect(html).to include("<strong>2</strong> completed in 90 days.")
      expect(html).not_to include("with recent confidence")
    end

    it "bolds all three counts" do
      html = helper.og_academy_goals_caption(active: 1, healthy_active: 1, completed_recent: 0)

      expect(html).to include("<strong>1</strong> active,")
      expect(html).to include("<strong>1</strong> with recent confidence.")
      expect(html).to include("<strong>0</strong> completed in 90 days.")
    end

    it "keeps the short phrasing for larger counts" do
      html = helper.og_academy_goals_caption(active: 3, healthy_active: 2, completed_recent: 1)

      expect(html).to include("<strong>3</strong> active,")
      expect(html).to include("<strong>2</strong> with recent confidence.")
      expect(html).to include("<strong>1</strong> completed in 90 days.")
    end
  end

  describe "#og_academy_check_in_stall_caption" do
    let(:stall) do
      CheckIns::OpenStallFinder::Stall.new(
        kind: :asymmetric,
        days: 6,
        waiting_on: :employee,
        object_name: "Frontend Craft",
        entity_type: "Assignment",
        item: nil,
        check_in: nil
      )
    end

    it "uses you when the viewer is the lagging employee" do
      caption = helper.og_academy_check_in_stall_caption(
        stall,
        teammate: teammate,
        viewer: teammate,
        employee_name: "Jamie",
        manager_name: "Alex"
      )
      expect(caption).to eq("Waiting on you — 6d")
    end

    it "uses the employee name when someone else is viewing" do
      viewer = create(:teammate, organization: organization)
      caption = helper.og_academy_check_in_stall_caption(
        stall,
        teammate: teammate,
        viewer: viewer,
        employee_name: "Jamie",
        manager_name: "Alex"
      )
      expect(caption).to eq("Waiting on Jamie — 6d")
    end

    it "formats stale review stalls" do
      review_stall = CheckIns::OpenStallFinder::Stall.new(
        kind: :stale_review,
        days: 4,
        waiting_on: :review,
        object_name: "Frontend Craft",
        entity_type: "Assignment",
        item: nil,
        check_in: nil
      )
      caption = helper.og_academy_check_in_stall_caption(
        review_stall,
        teammate: teammate,
        viewer: teammate,
        employee_name: "Jamie",
        manager_name: "Alex"
      )
      expect(caption).to eq("Review waiting — 4d")
    end
  end

  describe "#og_academy_check_in_primary_caption" do
    it "falls back to percent clear when there is no stall" do
      breakdown = EngagementHealth::ClarityActionMetrics::SlotBreakdown.new(
        healthy_slots: 2,
        warning_slots: 0,
        needs_attention_slots: 1,
        total_slots: 3,
        healthy_percentage: 66.7,
        warning_percentage: 0.0,
        needs_attention_percentage: 33.3
      )
      stall, caption = helper.og_academy_check_in_primary_caption(
        clarity_records: [],
        action_breakdown: breakdown,
        teammate: teammate,
        viewer: teammate,
        employee_name: "Jamie",
        manager_name: "Alex"
      )
      expect(stall).to be_nil
      expect(caption).to eq("66.7% clear")
    end
  end
end
