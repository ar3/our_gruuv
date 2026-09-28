# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssignmentsByDepartmentForSwitcher do
  let(:organization) { create(:organization) }
  let!(:dept_b) { create(:department, company: organization, name: "Beta Dept") }
  let!(:dept_a) { create(:department, company: organization, name: "Alpha Dept") }
  let!(:no_dept) { create(:assignment, company: organization, title: "Zulu Solo", department: nil) }
  let!(:in_b) { create(:assignment, company: organization, title: "Bravo Role", department: dept_b) }
  let!(:in_a2) { create(:assignment, company: organization, title: "Charlie Role", department: dept_a) }
  let!(:in_a1) { create(:assignment, company: organization, title: "Alpha Role", department: dept_a) }

  it "groups by department with no-department first, then alpha departments and titles" do
    result = described_class.call(scope: Assignment.where(company: organization))
    expect(result.keys.map { |d| d&.name }).to eq([nil, "Alpha Dept", "Beta Dept"])
    expect(result[nil].map(&:title)).to eq(["Zulu Solo"])
    expect(result[dept_a].map(&:title)).to eq(["Alpha Role", "Charlie Role"])
    expect(result[dept_b].map(&:title)).to eq(["Bravo Role"])
  end
end
