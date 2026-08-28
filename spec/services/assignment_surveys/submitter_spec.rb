require "rails_helper"

RSpec.describe AssignmentSurveys::Submitter do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, :assigned_employee, organization: organization) }
  let(:assignment_a) { create(:assignment, company: organization, title: "Alpha") }
  let(:assignment_b) { create(:assignment, company: organization, title: "Beta") }

  it "submits contentful in-progress responses" do
    first = create(:assignment_survey_response, :partial, company_teammate: teammate, assignment: assignment_a)
    second = create(:assignment_survey_response, company_teammate: teammate, assignment: assignment_b)

    submitted = described_class.new(teammate: teammate, organization: organization).call

    expect(submitted).to contain_exactly(first)
    expect(first.reload).to be_submitted
    expect(second.reload).to be_in_progress
  end

  it "can submit a single response by id" do
    first = create(:assignment_survey_response, :partial, company_teammate: teammate, assignment: assignment_a)
    create(:assignment_survey_response, :complete, company_teammate: teammate, assignment: assignment_b, submitted_at: nil)

    submitted = described_class.new(
      teammate: teammate,
      organization: organization,
      response_ids: [ first.id ]
    ).call

    expect(submitted).to contain_exactly(first)
  end
end
