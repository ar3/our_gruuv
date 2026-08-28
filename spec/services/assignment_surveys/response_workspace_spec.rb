require "rails_helper"

RSpec.describe AssignmentSurveys::ResponseWorkspace do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, :assigned_employee, organization: organization) }
  let!(:employment_tenure) do
    create(:employment_tenure, company_teammate: teammate, company: organization)
  end
  let(:assignment) { create(:assignment, company: organization) }
  let!(:assignment_tenure) do
    create(:assignment_tenure, teammate: teammate, assignment: assignment)
  end

  it "creates in-progress responses for active assignments" do
    responses = described_class.new(organization: organization, teammate: teammate).call

    expect(responses.size).to eq(1)
    expect(responses.first).to be_in_progress
    expect(responses.first.assignment_id).to eq(assignment.id)
  end

  it "reuses existing in-progress responses" do
    existing = create(:assignment_survey_response, company_teammate: teammate, assignment: assignment)

    responses = described_class.new(organization: organization, teammate: teammate).call

    expect(responses.map(&:id)).to eq([ existing.id ])
  end

  it "can scope to a single assignment" do
    other = create(:assignment, company: organization)
    create(:assignment_tenure, teammate: teammate, assignment: other)

    responses = described_class.new(
      organization: organization,
      teammate: teammate,
      assignment_ids: [ assignment.id ]
    ).call

    expect(responses.map(&:assignment_id)).to eq([ assignment.id ])
  end
end
