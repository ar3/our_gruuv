# frozen_string_literal: true

require "rails_helper"

RSpec.describe MyGrowthExperiencesHelper, type: :helper do
  include AssociableGoalsHelper

  let(:assignment) { build_stubbed(:assignment, title: "Ship Widgets") }

  describe "#my_growth_catalog_goals_popover_html" do
    it "lists confidence lines and always includes the see-all footer" do
      open_goals = [
        { title: "Ship onboarding", confidence_percentage: 75, confidence_saved_at: Time.zone.parse("2026-03-12 15:00") },
        { title: "Draft goal", confidence_percentage: nil, confidence_saved_at: nil }
      ]

      html = helper.my_growth_catalog_goals_popover_html(associable: assignment, open_goals: open_goals)

      expect(html).to include("Ship onboarding — 75% as of")
      expect(html).to include("Draft goal — no confidence yet")
      expect(html).to include("to see all of the goals, click on the Ship Widgets name link above")
    end

    it "truncates listed goals to the display limit but still shows the see-all footer" do
      open_goals = (1..6).map do |n|
        { title: "Goal #{n}", confidence_percentage: nil, confidence_saved_at: nil }
      end

      html = helper.my_growth_catalog_goals_popover_html(associable: assignment, open_goals: open_goals)

      expect(html).to include("Goal 1")
      expect(html).to include("Goal 5")
      expect(html).not_to include("Goal 6")
      expect(html).to include("to see all of the goals, click on the Ship Widgets name link above")
    end
  end

  describe "#missing_goals_active_goals_badge" do
    it "renders a popover badge when goals are present" do
      html = helper.missing_goals_active_goals_badge(
        associable: assignment,
        active_goals: [{ title: "Ship onboarding", confidence_percentage: nil, confidence_saved_at: nil }],
        count: 1
      )

      expect(html).to include("1 active goal")
      expect(html).to include('data-bs-toggle="popover"')
      expect(html).to include("Ship onboarding")
    end

    it "renders a plain badge when goals are blank" do
      html = helper.missing_goals_active_goals_badge(associable: assignment, active_goals: [], count: 0)

      expect(html).to include("0 active goals")
      expect(html).not_to include("data-bs-toggle")
    end
  end

  describe "#teammate_draft_goals_index_path" do
    let(:organization) { build_stubbed(:organization) }
    let(:teammate) { build_stubbed(:teammate, organization: organization) }

    it "filters goals index by teammate owner and draft status" do
      path = helper.teammate_draft_goals_index_path(organization, teammate, return_url: "/back", return_text: "Back")

      expect(path).to include("owner_id=CompanyTeammate_#{teammate.id}")
      expect(path).to include("status=draft")
      expect(path).to include("view=hierarchical-collapsible")
    end
  end
end
