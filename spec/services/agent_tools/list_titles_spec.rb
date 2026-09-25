# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::ListTitles, type: :service do
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
  let(:department) { create(:department, company: organization, name: "Engineering") }
  let(:major) { create(:position_major_level, major_level: 2, set_name: "Base-#{SecureRandom.hex(4)}") }
  let(:level_a) { create(:position_level, position_major_level: major, level: "2.1") }
  let(:level_b) { create(:position_level, position_major_level: major, level: "2.2") }
  let!(:title) do
    create(
      :title,
      company: organization,
      position_major_level: major,
      department: department,
      external_title: "Software Engineer",
      end_cap: false
    )
  end
  let!(:position_a) { create(:position, title: title, position_level: level_a) }
  let!(:position_b) { create(:position, title: title, position_level: level_b) }
  let(:dest_major) { create(:position_major_level, major_level: 3, set_name: "Base-#{SecureRandom.hex(4)}") }
  let!(:dest_title) do
    create(:title, company: organization, position_major_level: dest_major, department: department, external_title: "Staff Engineer")
  end

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:title_path, from_title: title, to_title: dest_title, path_type: "natural_progression")
  end

  it "returns path_clarity B fields, department filter, and child positions when expensive" do
    dept_path = AgentTools::RecordPaths.department_path(context, department)
    result = described_class.call(context: context, department_path: dept_path, limit: 50)

    expect(result.ok?).to be(true)
    expect(result.data[:note]).to include("Titles do not carry Assignments")
    expect(result.data[:path_clarity_definition]).to include("outbound")

    row = result.data[:titles].find { |t| t[:title] == "Software Engineer" }
    expect(row[:carries_assignments]).to be(false)
    expect(row[:end_cap]).to be(false)
    expect(row[:path_clarity]).to be(true)
    expect(row[:path_clarity_reason]).to eq("has_outbound")
    expect(row[:department]).to include(name: "Engineering")
    expect(row[:positions].map { |p| p[:level] }).to eq(%w[2.1 2.2])
    expect(row[:outbound_paths].first).to include(
      path_type: "natural_progression",
      title: "Staff Engineer"
    )
  end

  it "marks titles with only inbound paths as path_clarity missing" do
    # dest_title has inbound from title (before) but no outbound and is not end_cap
    result = described_class.call(context: context, query: "Staff", detail: "minimal", limit: 50)

    expect(result.ok?).to be(true)
    row = result.data[:titles].find { |t| t[:title] == "Staff Engineer" }
    expect(row[:path_clarity]).to be(false)
    expect(row[:path_clarity_reason]).to eq("missing")
    expect(row).not_to have_key(:positions)
  end

  it "treats end_cap as path_clarity clear" do
    ceo_major = create(:position_major_level, major_level: 5, set_name: "Base-#{SecureRandom.hex(4)}")
    create(
      :title,
      company: organization,
      position_major_level: ceo_major,
      department: department,
      external_title: "CEO",
      end_cap: true
    )

    result = described_class.call(context: context, query: "CEO", detail: "minimal", limit: 50)
    row = result.data[:titles].find { |t| t[:title] == "CEO" }
    expect(row[:path_clarity]).to be(true)
    expect(row[:path_clarity_reason]).to eq("end_cap")
  end
end
