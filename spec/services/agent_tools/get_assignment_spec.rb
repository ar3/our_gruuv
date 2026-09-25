# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::GetAssignment, type: :service do
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
  let(:assignment) do
    create(
      :assignment,
      company: organization,
      title: "Engineering Flow Architect",
      tagline: "Own the flow",
      handbook: "Docs"
    )
  end
  let(:ability) { create(:ability, company: organization, name: "Software Investigation") }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:assignment_outcome, assignment: assignment, description: "Smooth delivery")
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 4)
  end

  it "returns body fields plus ability links without milestone prose" do
    path = AgentTools::RecordPaths.assignment_path(context, assignment)
    result = described_class.call(context: context, path: path)

    expect(result.ok?).to be(true)
    row = result.data[:assignment]
    expect(row).to include(
      title: "Engineering Flow Architect",
      tagline: "Own the flow",
      handbook: "Docs",
      outcomes: ["Smooth delivery"]
    )
    expect(row[:abilities]).to contain_exactly(
      hash_including(name: "Software Investigation", milestone_level: 4)
    )
    expect(row[:abilities].first.keys).to contain_exactly(:name, :path, :milestone_level)
  end

  it "errors when path missing" do
    result = described_class.call(context: context)
    expect(result.ok?).to be(false)
    expect(result.error_code).to eq("validation_failed")
  end
end
