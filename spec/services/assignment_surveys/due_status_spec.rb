require "rails_helper"

RSpec.describe AssignmentSurveys::DueStatus do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  it "is due when never submitted" do
    result = described_class.for(teammate: teammate, assignment: assignment)

    expect(result).to be_due
    expect(result).to be_never_submitted
  end

  it "is early when feedback is newer than check-ins and assignment updates" do
    create(:assignment_survey_response, :partial, :submitted, company_teammate: teammate, assignment: assignment)
    assignment.update_columns(updated_at: 2.days.ago)

    result = described_class.for(teammate: teammate, assignment: assignment)

    expect(result).to be_early
    expect(result).not_to be_due
  end

  it "is due after an employee check-in since the last response" do
    create(
      :assignment_survey_response,
      :partial,
      company_teammate: teammate,
      assignment: assignment,
      submitted_at: 3.days.ago
    )
    assignment.update_columns(updated_at: 5.days.ago)
    create(
      :assignment_check_in,
      company_teammate: teammate,
      assignment: assignment,
      employee_completed_at: 1.day.ago
    )

    result = described_class.for(teammate: teammate, assignment: assignment)

    expect(result).to be_due
    expect(result.reason).to eq(:check_in_since)
  end
end
