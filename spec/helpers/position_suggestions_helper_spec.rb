require "rails_helper"

RSpec.describe PositionSuggestionsHelper, type: :helper do
  let(:organization) { create(:organization) }
  let(:assignment) do
    create(
      :assignment,
      company: organization,
      title: "Client Discovery",
      tagline: "Discover **client** needs",
      required_activities: "- Interview stakeholders\n- Write brief",
      handbook: "## How we do discovery"
    )
  end

  before do
    create(:assignment_outcome, assignment: assignment, description: "Capture top priorities")
  end

  describe "#position_suggestion_relative_time" do
    it "returns relative text with absolute title for hover" do
      time = 2.days.ago
      html = helper.position_suggestion_relative_time(time, viewer: create(:person))

      expect(html).to include("ago")
      expect(html).to include("title=")
    end
  end

  describe "#position_suggestion_assignment_popover_html" do
    it "includes tagline, outcomes, required activities, and a handbook visit note" do
      html = helper.position_suggestion_assignment_popover_html(assignment)

      expect(html).to include("Description")
      expect(html).to include("<strong>client</strong>")
      expect(html).to include("Outcomes")
      expect(html).to include("Capture top priorities")
      expect(html).to include("Required activities")
      expect(html).to include("Interview stakeholders")
      expect(html).to include("handbook content")
      expect(html).to include("Visit the assignment page")
      expect(html).not_to include("## How we do discovery")
    end

    it "omits the handbook note when handbook is blank" do
      assignment.update!(handbook: nil)
      html = helper.position_suggestion_assignment_popover_html(assignment)

      expect(html).not_to include("handbook content")
    end
  end

  describe "#position_suggestion_ability_description_popover_html" do
    it "renders markdown description" do
      ability = create(:ability, company: organization, name: "Communication", description: "Listen **carefully**")
      html = helper.position_suggestion_ability_description_popover_html(ability)

      expect(html).to include("<strong>carefully</strong>")
    end
  end
end
