# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssignmentSurveys::CheckInAlignmentBackfill do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  def create_eligible_check_in(**attrs)
    create(
      :assignment_check_in,
      :employee_completed,
      teammate: teammate,
      assignment: assignment,
      employee_personal_alignment: "love",
      employee_completed_at: 3.days.ago,
      **attrs
    )
  end

  it "creates a submitted alignment-only survey response from an eligible check-in" do
    check_in = create_eligible_check_in

    result = described_class.call(dry_run: false)

    expect(result.created).to eq(1)
    response = AssignmentSurveyResponse.find_by!(source_assignment_check_in_id: check_in.id)
    expect(response).to be_submitted
    expect(response.personal_alignment).to eq("love")
    expect(response.submitted_at).to be_within(1.second).of(check_in.employee_completed_at)
    expect(response.understandable_rating).to be_nil
    expect(response.possible_rating).to be_nil
    expect(response.relevant_rating).to be_nil
    expect(response.teammate_id).to eq(teammate.id)
    expect(response.organization_id).to eq(organization.id)
    expect(response.assignment_id).to eq(assignment.id)
    expect(response.snapshot_title).to eq(assignment.title)
  end

  it "skips check-ins without alignment or without employee completion" do
    create(
      :assignment_check_in,
      :employee_completed,
      teammate: teammate,
      assignment: assignment,
      employee_personal_alignment: nil
    )
    create(
      :assignment_check_in,
      teammate: teammate,
      assignment: create(:assignment, company: organization),
      employee_personal_alignment: "like",
      employee_completed_at: nil
    )

    result = described_class.call(dry_run: false)

    expect(result.scanned).to eq(0)
    expect(AssignmentSurveyResponse.where(teammate_id: teammate.id)).to be_empty
  end

  it "is idempotent when re-run" do
    check_in = create_eligible_check_in

    expect(described_class.call(dry_run: false).created).to eq(1)
    expect(described_class.call(dry_run: false).skipped).to eq(1)
    expect(AssignmentSurveyResponse.where(source_assignment_check_in_id: check_in.id).count).to eq(1)
  end

  it "adds history alongside existing survey submissions without overwriting them" do
    existing = create(
      :assignment_survey_response,
      :complete,
      company_teammate: teammate,
      assignment: assignment,
      personal_alignment: "like",
      submitted_at: 1.day.ago
    )
    check_in = create_eligible_check_in(employee_completed_at: 5.days.ago, employee_personal_alignment: "neutral")

    described_class.call(dry_run: false)

    expect(existing.reload.personal_alignment).to eq("like")
    expect(existing.understandable_rating).to eq(5)
    backfilled = AssignmentSurveyResponse.find_by!(source_assignment_check_in_id: check_in.id)
    expect(backfilled.personal_alignment).to eq("neutral")
    expect(AssignmentSurveyResponse.where(teammate_id: teammate.id, assignment_id: assignment.id).count).to eq(2)
  end

  it "creates one row per eligible check-in for the same assignment" do
    older = create(
      :assignment_check_in,
      :officially_completed,
      teammate: teammate,
      assignment: assignment,
      employee_personal_alignment: "only_if_necessary",
      employee_completed_at: 10.days.ago,
      official_check_in_completed_at: 9.days.ago
    )
    newer = create(
      :assignment_check_in,
      :employee_completed,
      teammate: teammate,
      assignment: assignment,
      employee_personal_alignment: "love",
      employee_completed_at: 2.days.ago
    )

    result = described_class.call(dry_run: false)

    expect(result.created).to eq(2)
    expect(AssignmentSurveyResponse.find_by!(source_assignment_check_in_id: older.id).personal_alignment)
      .to eq("only_if_necessary")
    expect(AssignmentSurveyResponse.find_by!(source_assignment_check_in_id: newer.id).personal_alignment)
      .to eq("love")
  end

  it "dry_run does not write rows" do
    create_eligible_check_in

    result = described_class.call(dry_run: true)

    expect(result.dry_run).to eq(true)
    expect(result.created).to eq(1)
    expect(AssignmentSurveyResponse.count).to eq(0)
  end
end
