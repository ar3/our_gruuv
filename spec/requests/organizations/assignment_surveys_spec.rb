require "rails_helper"

RSpec.describe "Assignment Experience Survey", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, :assigned_employee, person: person, organization: organization)
  end
  let!(:employment_tenure) do
    create(:employment_tenure, company_teammate: teammate, company: organization)
  end
  let(:assignment) { create(:assignment, :with_outcomes, company: organization) }
  let!(:assignment_tenure) do
    create(:assignment_tenure, teammate: teammate, assignment: assignment)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, organization)
  end

  it "renders the beta survey and creates a personalized draft" do
    get organization_assignment_survey_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Assignment Experience Survey")
    expect(response.body).to include("Beta")
    expect(response.body).to include("This survey is identifiable")

    post organization_assignment_survey_path(organization)

    expect(response).to redirect_to(organization_assignment_survey_path(organization))
    submission = teammate.assignment_survey_submissions.draft.first
    expect(submission.responses.map(&:assignment_id)).to eq([ assignment.id ])
  end

  it "autosaves and finalizes a complete survey" do
    submission = AssignmentSurveys::DraftBuilder.new(
      organization: organization,
      teammate: teammate
    ).call
    survey_response = submission.responses.first
    response_params = {
      "0" => {
        id: survey_response.id,
        understandable_rating: 5,
        possible_rating: 4,
        relevant_rating: 6,
        comment: "Clear and useful"
      }
    }

    patch organization_assignment_survey_path(organization),
          params: {
            autosave: "1",
            assignment_survey_submission: { responses_attributes: response_params }
          },
          headers: { "ACCEPT" => "application/json" }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include("ok" => true)
    expect(survey_response.reload.comment).to eq("Clear and useful")

    patch organization_assignment_survey_path(organization),
          params: {
            finalize: "1",
            assignment_survey_submission: { responses_attributes: response_params }
          }

    expect(response).to redirect_to(organization_assignment_survey_path(organization))
    expect(submission.reload).to be_finalized
  end

  it "rejects finalization when ratings are incomplete" do
    AssignmentSurveys::DraftBuilder.new(organization: organization, teammate: teammate).call

    patch organization_assignment_survey_path(organization),
          params: {
            finalize: "1",
            assignment_survey_submission: { responses_attributes: {} }
          }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Every assignment needs all three ratings")
    expect(teammate.assignment_survey_submissions.draft).to exist
  end

  it "shows results and exports CSV" do
    submission = AssignmentSurveys::DraftBuilder.new(organization: organization, teammate: teammate).call
    submission.responses.each do |survey_response|
      survey_response.update!(
        understandable_rating: 5,
        possible_rating: 4,
        relevant_rating: 6
      )
    end
    submission.finalize!

    get results_organization_assignment_survey_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Current overall results")
    expect(response.body).to include(person.display_name)

    get export_organization_assignment_survey_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.content_type).to include("text/csv")
    expect(response.body).to include("Understandable (1-6)")
    expect(response.body).to include("5")
  end

  context "when signed in as a manager" do
    let(:manager_person) { create(:person) }
    let(:manager) do
      create(:teammate, :assigned_employee, person: manager_person, organization: organization)
    end
    let(:peer_person) { create(:person) }
    let(:peer) do
      create(:teammate, :assigned_employee, person: peer_person, organization: organization)
    end

    before do
      create(:employment_tenure, company_teammate: manager, company: organization)
      create(:employment_tenure, company_teammate: peer, company: organization)
      employment_tenure.update!(manager_teammate: manager)
      AssignmentSurveys::DraftBuilder.new(organization: organization, teammate: teammate).call
      sign_in_as_teammate_for_request(manager_person, organization)
    end

    it "can see a report's draft answers" do
      get results_organization_assignment_survey_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(person.display_name)
      expect(response.body).to include("View draft")
      expect(response.body).not_to include(peer_person.display_name)
    end
  end
end
