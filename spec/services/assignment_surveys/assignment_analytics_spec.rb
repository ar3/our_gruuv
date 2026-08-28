require "rails_helper"

RSpec.describe AssignmentSurveys::AssignmentAnalytics do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:viewer) { create(:teammate, :assigned_employee, organization: organization, can_manage_maap: true) }
  let(:respondent) { create(:teammate, :assigned_employee, organization: organization) }

  before do
    create(:employment_tenure, company_teammate: viewer, company: organization)
    create(:employment_tenure, company_teammate: respondent, company: organization)
    create(
      :assignment_survey_response,
      :partial,
      :submitted,
      company_teammate: respondent,
      assignment: assignment,
      understandable_rating: 5,
      comment: "Needs clearer outcomes"
    )
  end

  it "exposes org-wide detail for MAAP managers and hides public aggregate below threshold" do
    result = described_class.new(
      assignment: assignment,
      viewer: viewer,
      organization: organization
    ).call

    expect(result.respondent_count).to eq(1)
    expect(result.public_threshold_met?).to be(false)
    expect(result.org_wide_eligible?).to be(true)
    expect(result.org_wide_rows.map { |row| row.teammate.id }).to eq([ respondent.id ])
    expect(result.org_wide_rows.first.comment).to eq("Needs clearer outcomes")
  end
end
