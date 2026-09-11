# frozen_string_literal: true

require "rails_helper"

RSpec.describe DepartmentsHealth::ExpectationAlignmentOverview do
  let(:organization) { create(:organization) }
  let(:major_level) { create(:position_major_level) }
  let(:department) { create(:department, company: organization, name: "Engineering") }

  it "aggregates title, position, and assignment EAS by department" do
    title = create(:title, company: organization, department: department, position_major_level: major_level, external_title: "Engineer")
    position_level = create(:position_level, position_major_level: major_level, level: "1.1")
    position = create(:position, title: title, position_level: position_level)
    assignment = create(:assignment, company: organization, department: department)

    TitleExpectationAlignmentScore.create!(
      title: title,
      organization: organization,
      score: 90,
      cells: [],
      path_clarity: true,
      calculated_at: Time.current
    )
    PositionExpectationAlignmentScore.create!(
      position: position,
      organization: organization,
      score: 70,
      cells: [],
      required_assignments_count: 0,
      calculated_at: Time.current
    )
    AssignmentExpectationAlignmentScore.create!(
      assignment: assignment,
      organization: organization,
      score: 50,
      cells: [],
      check_in_teammate_count: 0,
      survey_respondent_count: 0,
      calculated_at: Time.current
    )

    result = described_class.call(organization: organization)
    eng = result.department_rows.find { |row| row.label == "Engineering" }

    expect(eng.titles.average_score).to eq(90.0)
    expect(eng.positions.average_score).to eq(70.0)
    expect(eng.assignments.average_score).to eq(50.0)
    expect(eng.combined_average).to eq(70.0)
    expect(result.department_count).to eq(1)
  end
end
