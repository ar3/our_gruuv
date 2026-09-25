# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::GetPosition, type: :service do
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
  let(:major) { create(:position_major_level, major_level: 2, set_name: "Base-#{SecureRandom.hex(4)}") }
  let(:level) { create(:position_level, position_major_level: major, level: "2.2") }
  let(:title) { create(:title, company: organization, position_major_level: major, external_title: "Engineer") }
  let!(:position) { create(:position, title: title, position_level: level) }
  let(:required_assignment) { create(:assignment, company: organization, title: "Ship Features") }
  let(:suggested_assignment) { create(:assignment, company: organization, title: "Optional Mentoring") }
  let(:assignment_ability) do
    create(:ability, company: organization, name: "Software Investigation",
                     milestone_3_description: "Can lead investigations")
  end
  let(:direct_ability) { create(:ability, company: organization, name: "Flow Architect") }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(
      :position_assignment,
      :required,
      position: position,
      assignment: required_assignment,
      min_estimated_energy: 50,
      max_estimated_energy: 50
    )
    create(
      :position_assignment,
      :suggested,
      position: position,
      assignment: suggested_assignment,
      max_estimated_energy: 10
    )
    create(:assignment_ability, assignment: required_assignment, ability: assignment_ability, milestone_level: 3)
    create(:assignment_ability, assignment: suggested_assignment, ability: create(:ability, company: organization, name: "Only On Suggested"), milestone_level: 2)
    create(:position_ability, position: position, ability: direct_ability, milestone_level: 4)
  end

  it "returns assignments with ability links and required_abilities rollup" do
    path = AgentTools::RecordPaths.position_path(context, position)
    result = described_class.call(context: context, path: path)

    expect(result.ok?).to be(true)
    pos = result.data[:position]

    required = pos[:assignments].find { |a| a[:title] == "Ship Features" }
    expect(required[:abilities]).to contain_exactly(
      hash_including(name: "Software Investigation", milestone_level: 3)
    )
    expect(required[:abilities].first).not_to have_key(:milestone_3_description)

    suggested = pos[:assignments].find { |a| a[:title] == "Optional Mentoring" }
    expect(suggested[:abilities].map { |a| a[:name] }).to include("Only On Suggested")

    names = pos[:required_abilities].map { |r| r[:name] }
    expect(names).to include("Software Investigation", "Flow Architect")
    expect(names).not_to include("Only On Suggested")

    investigation = pos[:required_abilities].find { |r| r[:name] == "Software Investigation" }
    expect(investigation[:minimum_milestone_level]).to eq(3)
    expect(investigation[:sources]).to include(
      hash_including(kind: "assignment", milestone_level: 3, assignment_title: "Ship Features")
    )

    direct = pos[:required_abilities].find { |r| r[:name] == "Flow Architect" }
    expect(direct[:sources]).to include(hash_including(kind: "direct", milestone_level: 4))
  end

  it "errors when path missing" do
    result = described_class.call(context: context)
    expect(result.ok?).to be(false)
    expect(result.error_code).to eq("validation_failed")
  end
end
