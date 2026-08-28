require "rails_helper"

RSpec.describe AssignmentSurveyResponse, type: :model do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  it "allows an in-progress response with partial content" do
    response = create(:assignment_survey_response, :partial, company_teammate: teammate, assignment: assignment)

    expect(response).to be_in_progress
    expect(response).to be_content
  end

  it "submits a contentful response and prevents edits afterward" do
    response = create(:assignment_survey_response, :partial, company_teammate: teammate, assignment: assignment)

    response.submit!

    expect(response.reload).to be_submitted
    expect(response.update(comment: "Changed")).to be(false)
    expect(response.errors.full_messages).to include("Submitted feedback cannot be changed")
  end

  it "allows only one in-progress response per teammate and assignment" do
    create(:assignment_survey_response, company_teammate: teammate, assignment: assignment)
    duplicate = build(:assignment_survey_response, company_teammate: teammate, assignment: assignment)

    expect(duplicate).not_to be_valid
  end
end
