# frozen_string_literal: true

require "rails_helper"

RSpec.describe JobDescriptionAcknowledgements::Document do
  let(:organization) { create(:organization) }
  let(:person) { create(:person, first_name: "Samantha", last_name: "Cartwright") }
  let(:teammate) { create(:teammate, person: person, organization: organization, first_employed_at: 1.year.ago) }
  let(:held_assignment) { create(:assignment, company: organization, title: "Build Widget") }
  let(:missing_assignment) { create(:assignment, company: organization, title: "Review Widget") }
  let(:ability) do
    create(
      :ability,
      company: organization,
      name: "Widget Craft",
      description: "Skill for making widgets.",
      milestone_2_description: "Builds widgets alone."
    )
  end

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    position = teammate.employment_tenures.find_by!(ended_at: nil).position
    create(:position_assignment, :required, position: position, assignment: held_assignment)
    create(:position_assignment, :required, position: position, assignment: missing_assignment)
    create(:assignment_ability, assignment: held_assignment, ability: ability, milestone_level: 2)
    create(:position_ability, position: position, ability: ability, milestone_level: 2)
    create(:assignment_tenure, teammate: teammate, assignment: held_assignment, anticipated_energy_percentage: 40, started_at: 1.month.ago)
  end

  it "records held assignment energy, missing required assignments, seat placeholders, and required abilities" do
    snapshot = described_class.call(teammate: teammate, organization: organization).snapshot

    expect(snapshot["required_assignments"]).to include(
      hash_including("title" => "Build Widget", "energy_percentage" => 40, "missing" => false, "kind" => "required"),
      hash_including("title" => "Review Widget", "energy_percentage" => 0, "missing" => true, "energy_unset" => false)
    )
    expect(snapshot["seat"]["present"]).to eq(false)
    expect(snapshot["casual_name"]).to eq("Samantha C.")
    expect(snapshot["required_abilities"]).to include(
      hash_including(
        "ability_name" => "Widget Craft",
        "description" => "Skill for making widgets.",
        "milestones" => [
          hash_including(
            "milestone_level" => 2,
            "markdown" => a_string_including("Builds widgets alone.", "Assignments that require at least this milestone:", "Build Widget", "Also required directly by the position.")
          )
        ]
      )
    )
  end
end
