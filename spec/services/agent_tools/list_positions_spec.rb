# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::ListPositions, type: :service do
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
  let(:level) { create(:position_level, position_major_level: major, level: "2.1") }
  let(:title) { create(:title, company: organization, position_major_level: major, external_title: "Software Engineer") }
  let!(:position) { create(:position, title: title, position_level: level) }
  let(:assignment) { create(:assignment, company: organization, title: "Code Review Lead") }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(
      :position_assignment,
      :required,
      position: position,
      assignment: assignment,
      min_estimated_energy: 20,
      max_estimated_energy: 40
    )
    create(
      :position_assignment,
      :suggested,
      position: position,
      assignment: create(:assignment, company: organization, title: "Optional Mentoring"),
      max_estimated_energy: 10
    )
  end

  it "returns positions with assignment energy and types by default" do
    result = described_class.call(context: context, limit: 50)

    expect(result.ok?).to be(true)
    expect(result.data[:detail]).to eq("expensive")
    expect(result.data[:note]).to include("Positions carry Assignments")

    row = result.data[:positions].find { |p| p[:display_name] == position.display_name }
    expect(row[:level]).to eq("2.1")
    expect(row[:title]).to include(title: "Software Engineer", carries_assignments: false)
    expect(row[:path]).to be_present

    types = row[:assignments].map { |a| a[:assignment_type] }
    expect(types).to include("required", "suggested")

    required = row[:assignments].find { |a| a[:title] == "Code Review Lead" }
    expect(required).to include(
      min_estimated_energy: 20,
      max_estimated_energy: 40,
      anticipated_energy_percentage: 30
    )
  end

  it "supports minimal detail and title_path filter" do
    other_major = create(:position_major_level, major_level: 3, set_name: "Base-#{SecureRandom.hex(4)}")
    other_level = create(:position_level, position_major_level: other_major, level: "3.1")
    other_title = create(:title, company: organization, position_major_level: other_major, external_title: "Staff Engineer")
    create(:position, title: other_title, position_level: other_level)

    title_path = AgentTools::RecordPaths.title_path(context, title)
    result = described_class.call(
      context: context,
      title_path: title_path,
      detail: "minimal",
      limit: 50
    )

    expect(result.ok?).to be(true)
    expect(result.data[:positions].size).to eq(1)
    expect(result.data[:positions].first.keys).to include(:display_name, :path, :level, :title)
    expect(result.data[:positions].first).not_to have_key(:assignments)
  end
end
