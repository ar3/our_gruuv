# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExpectationsCompliance::Roster do
  let(:organization) { create(:organization) }
  let(:manager_person) { create(:person, first_name: "Morgan", last_name: "Manager") }
  let(:employee_person) { create(:person, first_name: "Sam", last_name: "Employee") }
  let(:manager) { create(:teammate, person: manager_person, organization: organization, first_employed_at: 1.year.ago) }
  let(:employee) { create(:teammate, person: employee_person, organization: organization, first_employed_at: 6.months.ago) }

  before do
    create(:employment_tenure, teammate: manager, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(
      :employment_tenure,
      teammate: employee,
      company: organization,
      manager_teammate: manager,
      started_at: 6.months.ago,
      ended_at: nil
    )
  end

  it "builds roster rows with tenure, manager, and report counts" do
    rows = described_class.call(organization: organization, teammates: [employee, manager])
    employee_row = rows.find { |row| row.teammate == employee }
    manager_row = rows.find { |row| row.teammate == manager }

    expect(employee_row.current_position_name).to be_present
    expect(employee_row.manager_name).to eq("Morgan M.")
    expect(employee_row.direct_report_count).to eq(0)
    expect(manager_row.direct_report_count).to eq(1)
    expect(manager_row.hierarchical_report_count).to eq(1)
  end

  it "marks overdue teammates ahead of signed ones" do
    acknowledgement = JobDescriptionAcknowledgement.new(
      company_teammate: manager,
      organization: organization,
      typed_name: manager_person.government_first_then_last_display_name,
      signed_at: Time.current,
      document_html: "<p>ok</p>",
      snapshot: { "position_name" => "Role" }
    )
    acknowledgement.save!(validate: false)

    rows = described_class.call(organization: organization, teammates: [employee, manager])
    expect(rows.first.teammate).to eq(employee)
    expect(rows.first.compliant).to eq(false)
    expect(rows.last.teammate).to eq(manager)
    expect(rows.last.compliant).to eq(true)
  end
end
