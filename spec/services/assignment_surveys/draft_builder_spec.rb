require "rails_helper"

RSpec.describe AssignmentSurveys::DraftBuilder do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, :assigned_employee, organization: organization) }
  let!(:employment_tenure) do
    create(:employment_tenure, company_teammate: teammate, company: organization)
  end

  it "snapshots active and required assignments, excludes suggested, and deduplicates overlap" do
    active = create(:assignment, :with_outcomes, company: organization, title: "Active work")
    required = create(:assignment, company: organization, title: "Required work")
    both = create(:assignment, company: organization, title: "Both kinds")
    suggested = create(:assignment, company: organization, title: "Suggested work")

    create(:assignment_tenure, teammate: teammate, assignment: active)
    create(:assignment_tenure, teammate: teammate, assignment: both)
    create(:position_assignment, :required, position: employment_tenure.position, assignment: required)
    create(:position_assignment, :required, position: employment_tenure.position, assignment: both)
    create(:position_assignment, :suggested, position: employment_tenure.position, assignment: suggested)

    submission = described_class.new(organization: organization, teammate: teammate).call

    expect(submission.responses.map(&:snapshot_title)).to contain_exactly("Active work", "Required work", "Both kinds")
    expect(submission.responses.index_by(&:snapshot_title).transform_values(&:assignment_source)).to eq(
      "Active work" => "active",
      "Required work" => "required",
      "Both kinds" => "active_and_required"
    )
    expect(submission.responses.find { |response| response.snapshot_title == "Active work" }.snapshot_outcomes.size).to eq(3)
  end

  it "returns the existing draft instead of creating another" do
    assignment = create(:assignment, company: organization)
    create(:assignment_tenure, teammate: teammate, assignment: assignment)
    builder = described_class.new(organization: organization, teammate: teammate)

    expect(builder.call).to eq(builder.call)
    expect(teammate.assignment_survey_submissions.draft.count).to eq(1)
  end

  it "includes active assignment tenures even when energy is zero" do
    zero_energy = create(:assignment, company: organization, title: "Zero energy work")
    create(
      :assignment_tenure,
      teammate: teammate,
      assignment: zero_energy,
      anticipated_energy_percentage: 0
    )

    submission = described_class.new(organization: organization, teammate: teammate).call

    expect(submission.responses.map(&:snapshot_title)).to contain_exactly("Zero energy work")
  end

  it "does not create an empty draft" do
    submission = described_class.new(organization: organization, teammate: teammate).call

    expect(submission).to be_nil
    expect(teammate.assignment_survey_submissions).to be_empty
  end
end
