# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::PeriodBriefContextBuilder do
  let(:organization) { create(:organization, :company) }
  let(:viewer_person) { create(:person, first_name: "Alex") }
  let!(:viewer) { create(:teammate, person: viewer_person, organization: organization) }
  let(:employee_person) { create(:person, first_name: "Pat") }
  let(:employee) { create(:teammate, person: employee_person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Ship weekly demos") }
  let(:check_in) do
    create(
      :assignment_check_in,
      teammate: employee,
      assignment: assignment,
      check_in_started_on: Date.current,
      official_check_in_completed_at: nil
    )
  end

  before do
    create(:assignment_tenure, teammate: employee, assignment: assignment, started_at: 30.days.ago)
  end

  it "includes only object-matched viewer-visible pOGOs in the period window" do
    other_assignment = create(:assignment, company: organization, title: "Other work")
    create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: employee,
      visibility: SlackPossibleObservation::VISIBILITY_PUBLIC,
      message_ts: 2.days.ago.to_f.to_s,
      payload: {
        "summary" => "Pat demoed the fallback path live",
        "confidence" => 0.91,
        "suggested_rateable_type" => "Assignment",
        "suggested_rateable_id" => assignment.id,
        "suggested_rateable_name" => assignment.title,
        "quote" => "Nailed the demo"
      }
    )
    create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: employee,
      visibility: SlackPossibleObservation::VISIBILITY_PUBLIC,
      message_ts: 1.day.ago.to_f.to_s,
      payload: {
        "summary" => "Unrelated other-assignment praise",
        "confidence" => 0.95,
        "suggested_rateable_type" => "Assignment",
        "suggested_rateable_id" => other_assignment.id,
        "suggested_rateable_name" => other_assignment.title
      }
    )
    create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: employee,
      visibility: SlackPossibleObservation::VISIBILITY_PUBLIC,
      message_ts: 60.days.ago.to_f.to_s,
      payload: {
        "summary" => "Old matched pOGO outside the period",
        "confidence" => 0.99,
        "suggested_rateable_type" => "Assignment",
        "suggested_rateable_id" => assignment.id,
        "suggested_rateable_name" => assignment.title
      }
    )

    result = described_class.call(
      organization: organization,
      viewer_person: viewer_person,
      teammate: employee,
      check_in: check_in,
      check_in_kind: "assignment"
    )

    expect(result.visibility_note).to include("prepared only for #{viewer_person.casual_name}")
    expect(result.preface).to include("for #{viewer_person.casual_name} only")
    expect(result.user_prompt).to include("object-matched")
    expect(result.user_prompt).to include("Pat demoed the fallback path live")
    expect(result.user_prompt).not_to include("Unrelated other-assignment praise")
    expect(result.user_prompt).not_to include("Old matched pOGO outside the period")
    expect(result.user_prompt).to include("LINKED / RELEVANT GOALS")
  end
end
