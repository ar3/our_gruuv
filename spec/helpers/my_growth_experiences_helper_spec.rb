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
end
