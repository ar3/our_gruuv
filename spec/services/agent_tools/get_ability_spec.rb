# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::GetAbility, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, :assigned_employee, person: person, organization: organization) }
  let(:context) do
    AgentTools::Context.new(
      organization: organization,
      person: person,
      company_teammate: teammate
    )
  end
  let(:ability) do
    create(
      :ability,
      company: organization,
      name: "Software Investigation",
      description: "Find root causes",
      milestone_1_description: "Follow a runbook",
      milestone_3_description: "Lead investigations",
      milestone_5_description: nil
    )
  end
  let(:assignment) { create(:assignment, company: organization, title: "Engineering Flow Architect") }
  let(:major) { create(:position_major_level, major_level: 2, set_name: "Base-#{SecureRandom.hex(4)}") }
  let(:level) { create(:position_level, position_major_level: major, level: "2.1") }
  let(:title) { create(:title, company: organization, position_major_level: major, external_title: "Engineer") }
  let!(:position_via_assignment) { create(:position, title: title, position_level: level) }
  let(:direct_major) { create(:position_major_level, major_level: 3, set_name: "Base-#{SecureRandom.hex(4)}") }
  let(:direct_level) { create(:position_level, position_major_level: direct_major, level: "3.1") }
  let(:direct_title) { create(:title, company: organization, position_major_level: direct_major, external_title: "Staff") }
  let!(:position_direct) { create(:position, title: direct_title, position_level: direct_level) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 3)
    create(:position_assignment, :required, position: position_via_assignment, assignment: assignment)
    create(:position_ability, position: position_direct, ability: ability, milestone_level: 4)

    suggested = create(:assignment, company: organization, title: "Suggested Only")
    create(:assignment_ability, assignment: suggested, ability: ability, milestone_level: 2)
    create(:position_assignment, :suggested, position: position_via_assignment, assignment: suggested)
  end

  it "returns full body plus reverse assignments and requiring positions" do
    path = AgentTools::RecordPaths.ability_path(context, ability)
    result = described_class.call(context: context, path: path)

    expect(result.ok?).to be(true)
    row = result.data[:ability]
    expect(row).to include(
      name: "Software Investigation",
      description: "Find root causes",
      milestone_1_description: "Follow a runbook",
      milestone_3_description: "Lead investigations",
      milestone_5_description: nil
    )
    expect(row[:assignments].map { |a| a[:title] }).to include(
      "Engineering Flow Architect",
      "Suggested Only"
    )
    expect(row[:assignments]).to include(hash_including(title: "Engineering Flow Architect", milestone_level: 3))

    names = row[:positions].map { |p| p[:display_name] }
    expect(names).to include(position_via_assignment.display_name, position_direct.display_name)

    via = row[:positions].find { |p| p[:display_name] == position_via_assignment.display_name }
    expect(via[:sources]).to include(hash_including(kind: "assignment", milestone_level: 3))
    # suggested assignment must not create a requiring-position source
    expect(via[:sources]).not_to include(hash_including(assignment_title: "Suggested Only"))

    direct = row[:positions].find { |p| p[:display_name] == position_direct.display_name }
    expect(direct[:sources]).to include(hash_including(kind: "direct", milestone_level: 4))
  end

  it "errors when path missing" do
    result = described_class.call(context: context)
    expect(result.ok?).to be(false)
    expect(result.error_code).to eq("validation_failed")
  end
end
