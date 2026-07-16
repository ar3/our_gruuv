require "rails_helper"

RSpec.describe AssignmentSurveys::Results do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  it "uses only each teammate's latest finalized submission in aggregates" do
    first = create(:assignment_survey_submission, company_teammate: teammate)
    create(
      :assignment_survey_response,
      submission: first,
      assignment: assignment,
      understandable_rating: 1,
      possible_rating: 1,
      relevant_rating: 1
    )
    first.finalize!

    second = create(:assignment_survey_submission, company_teammate: teammate)
    create(
      :assignment_survey_response,
      submission: second,
      assignment: assignment,
      understandable_rating: 6,
      possible_rating: 5,
      relevant_rating: 4
    )
    second.finalize!

    results = described_class.new(
      organization: organization,
      teammates: CompanyTeammate.where(id: teammate.id)
    )

    understandable = results.overall_distributions.fetch(:understandable)
    expect(understandable[:total]).to eq(1)
    expect(understandable[:counts].fetch(1)).to eq(0)
    expect(understandable[:counts].fetch(6)).to eq(1)
    expect(results.participation_rows.first[:submission_count]).to eq(2)
  end
end
