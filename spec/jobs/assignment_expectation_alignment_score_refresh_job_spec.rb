# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssignmentExpectationAlignmentScoreRefreshJob, type: :job do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }

  it "persists the expectation alignment score for the assignment" do
    teammate = create(:teammate, :assigned_employee, organization: organization)
    create(:employment_tenure, company_teammate: teammate, company: organization)
    create(
      :assignment_check_in,
      :officially_completed,
      teammate: teammate,
      assignment: assignment,
      employee_rating: "meeting",
      manager_rating: "meeting"
    )

    expect {
      described_class.perform_now(assignment.id)
    }.to change(AssignmentExpectationAlignmentScore, :count).by(1)

    expect(assignment.reload.expectation_alignment_score_cache.score.to_f).to eq(100.0)
  end

  it "no-ops when the assignment is missing" do
    expect {
      described_class.perform_now(-1)
    }.not_to change(AssignmentExpectationAlignmentScore, :count)
  end
end

RSpec.describe DailyRefreshAssignmentExpectationAlignmentScoresJob, type: :job do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }

  it "enqueues a refresh for each persisted score row" do
    AssignmentExpectationAlignmentScore.create!(
      assignment: assignment,
      organization: organization,
      score: 50,
      cells: [],
      check_in_teammate_count: 2,
      survey_respondent_count: 0,
      calculated_at: 1.day.ago
    )
    other = create(:assignment, company: organization)
    AssignmentExpectationAlignmentScore.create!(
      assignment: other,
      organization: organization,
      score: nil,
      cells: [],
      check_in_teammate_count: 0,
      survey_respondent_count: 0,
      calculated_at: 1.day.ago
    )

    expect {
      described_class.perform_now
    }.to have_enqueued_job(AssignmentExpectationAlignmentScoreRefreshJob).exactly(2).times
  end
end
