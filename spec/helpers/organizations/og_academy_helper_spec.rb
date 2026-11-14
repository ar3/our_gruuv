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
end
