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
    expect(assignment_row[:overall_average]).to eq(5.0)
  end

  describe "assignment sort" do
    let(:alpha) { create(:assignment, company: organization, title: "Alpha role") }
    let(:middle) { create(:assignment, company: organization, title: "Middle role") }
    let(:zeta) { create(:assignment, company: organization, title: "Zeta role") }

    before do
      other = create(:teammate, :assigned_employee, organization: organization)

      teammate_submission = create(:assignment_survey_submission, company_teammate: teammate)
      [
        [ alpha, 4, 4, 4 ],
        [ middle, 2, 2, 2 ],
        [ zeta, 6, 6, 6 ]
      ].each do |rated_assignment, understandable, possible, relevant|
        create(
          :assignment_survey_response,
          submission: teammate_submission,
          assignment: rated_assignment,
          snapshot_title: rated_assignment.title,
          understandable_rating: understandable,
          possible_rating: possible,
          relevant_rating: relevant
        )
      end
      teammate_submission.finalize!

      other_submission = create(:assignment_survey_submission, company_teammate: other)
      create(
        :assignment_survey_response,
        submission: other_submission,
        assignment: middle,
        snapshot_title: middle.title,
        understandable_rating: 1,
        possible_rating: 1,
        relevant_rating: 1
      )
      other_submission.finalize!
    end

    def titles_for(sort)
      described_class.new(
        organization: organization,
        teammates: CompanyTeammate.where(id: organization.company_teammates.select(:id)),
        assignment_sort: sort
      ).assignment_rows.map { |row| row[:title] }
    end

    it "defaults to alphabetical name order" do
      expect(titles_for("name")).to eq([ "Alpha role", "Middle role", "Zeta role" ])
      expect(titles_for("bogus")).to eq([ "Alpha role", "Middle role", "Zeta role" ])
    end

    it "sorts by overall average lowest first" do
      expect(titles_for("average")).to eq([ "Middle role", "Alpha role", "Zeta role" ])
    end

    it "sorts by response count highest first" do
      expect(titles_for("responses")).to eq([ "Middle role", "Alpha role", "Zeta role" ])
    end
  end
end
