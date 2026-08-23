# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::BulkAcknowledgeCheckInsService do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:teammate) { create(:company_teammate, person: employee, organization: organization, first_employed_at: 1.year.ago) }
  let!(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago) }
  let(:assignment_a) { create(:assignment, company: organization, title: "Alpha") }
  let(:assignment_b) { create(:assignment, company: organization, title: "Beta") }
  let!(:check_in_a) do
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment_a,
           official_check_in_completed_at: 1.day.ago)
  end
  let!(:check_in_b) do
    create(:assignment_check_in, :officially_completed,
           teammate: teammate,
           assignment: assignment_b,
           official_check_in_completed_at: 1.day.ago)
  end

  it "saves agree/disagree and skips leave_unacknowledged" do
    result = described_class.call(
      teammate: teammate,
      acknowledgements: {
        "assignment" => {
          check_in_a.id.to_s => {
            "employee_acknowledgement" => "agree",
            "employee_acknowledgement_notes" => "Yep"
          },
          check_in_b.id.to_s => {
            "employee_acknowledgement" => "leave_unacknowledged"
          }
        }
      }
    )

    expect(result).to be_ok
    expect(result.value[:saved]).to eq(1)
    expect(result.value[:skipped]).to eq(1)
    expect(check_in_a.reload).to be_employee_acknowledgement_agree
    expect(check_in_a.employee_acknowledgement_notes).to eq("Yep")
    expect(check_in_b.reload.employee_acknowledged_at).to be_nil
  end
end
