require "rails_helper"

RSpec.describe AssignmentSurveySubmission, type: :model do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  it "allows a draft with incomplete responses" do
    submission = create(:assignment_survey_submission, company_teammate: teammate)
    create(:assignment_survey_response, submission: submission, assignment: assignment)

    expect(submission.reload).to be_draft
  end

  it "requires every response to be complete before finalizing" do
    submission = create(:assignment_survey_submission, company_teammate: teammate)
    create(:assignment_survey_response, submission: submission, assignment: assignment)

    expect { submission.finalize! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(submission.reload).to be_draft
  end

  it "finalizes a complete submission and prevents response edits" do
    submission = create(:assignment_survey_submission, company_teammate: teammate)
    response = create(
      :assignment_survey_response,
      :complete,
      submission: submission,
      assignment: assignment
    )

    submission.finalize!

    expect(submission.reload).to be_finalized
    expect(submission.finalized_at).to be_present
    expect(submission.update(finalized_at: 1.day.from_now)).to be(false)
    expect(submission.errors.full_messages).to include("Finalized survey submissions cannot be changed")
    expect(response.update(comment: "Changed later")).to be(false)
    expect(response.errors.full_messages).to include("Finalized survey responses cannot be changed")
  end

  it "allows only one draft per teammate" do
    create(:assignment_survey_submission, company_teammate: teammate)
    second = build(:assignment_survey_submission, company_teammate: teammate)

    expect(second).not_to be_valid
  end
end
