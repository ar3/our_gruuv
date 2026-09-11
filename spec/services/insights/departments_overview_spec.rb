# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::DepartmentsOverview do
  let(:organization) { create(:organization, :company) }

  it "computes averages and chart series per department" do
    engineering = create(:department, company: organization, name: "Engineering")
    sales = create(:department, company: organization, name: "Sales")
    create(:assignment, company: organization, department: engineering)
    create(:assignment, company: organization, department: engineering)
    create(:ability, company: organization, department: engineering)
    create(:assignment, company: organization, department: sales)

    result = described_class.call(organization: organization)

    expect(result.departments_count).to eq(2)
    expect(result.average_assignments_per_department).to eq(1.5)
    expect(result.average_abilities_per_department).to eq(0.5)
    expect(result.chart_data[:categories]).to include("Engineering", "Sales")
    expect(result.chart_data[:series].map { |s| s[:name] }).to eq(%w[Assignments Abilities Seats])
  end
end
