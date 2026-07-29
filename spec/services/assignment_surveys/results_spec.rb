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
    expect(understandable[:rating_sets].fetch(6)).to eq(teammate_count: 1, assignment_count: 1)
    expect(results.participation_rows.first[:submission_count]).to eq(2)
  end

  it "counts distinct teammates and assignments in each rating set" do
    other_teammate = create(:teammate, :assigned_employee, organization: organization)
    other_assignment = create(:assignment, company: organization)

    [ teammate, other_teammate ].each do |survey_teammate|
      submission = create(:assignment_survey_submission, company_teammate: survey_teammate)
      create(
        :assignment_survey_response,
        submission: submission,
        assignment: assignment,
        understandable_rating: 6,
        possible_rating: 5,
        relevant_rating: 4
      )
      create(
        :assignment_survey_response,
        submission: submission,
        assignment: other_assignment,
        understandable_rating: 6,
        possible_rating: 3,
        relevant_rating: 2
      )
      submission.finalize!
    end

    results = described_class.new(
      organization: organization,
      teammates: CompanyTeammate.where(id: [ teammate.id, other_teammate.id ])
    )

    understandable = results.overall_distributions.fetch(:understandable)
    expect(understandable[:counts].fetch(6)).to eq(4)
    expect(understandable[:rating_sets].fetch(6)).to eq(teammate_count: 2, assignment_count: 2)

    assignment_row = results.assignment_rows.find { |row| row[:assignment_id] == assignment.id }
    expect(assignment_row[:distributions].dig(:understandable, :average)).to eq(6.0)
    expect(assignment_row[:distributions].dig(:possible, :average)).to eq(5.0)
    expect(assignment_row[:distributions].dig(:relevant, :average)).to eq(4.0)
  end
end
