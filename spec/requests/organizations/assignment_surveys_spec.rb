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

  it "deletes a draft" do
    AssignmentSurveys::DraftBuilder.new(organization: organization, teammate: teammate).call

    delete organization_assignment_survey_path(organization)

    expect(response).to redirect_to(organization_assignment_survey_path(organization))
    expect(teammate.assignment_survey_submissions.draft).not_to exist
  end

  it "asks for confirmation before starting another survey within 30 days" do
    submission = AssignmentSurveys::DraftBuilder.new(organization: organization, teammate: teammate).call
    submission.responses.each do |survey_response|
      survey_response.update!(
        understandable_rating: 5,
        possible_rating: 4,
        relevant_rating: 6
      )
    end
    submission.finalize!

    get organization_assignment_survey_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("less than 30 days ago")
    expect(response.body).to include("Start another one anyway?")
  end

  it "does not ask for confirmation when the latest survey is older than 30 days" do
    submission = AssignmentSurveys::DraftBuilder.new(organization: organization, teammate: teammate).call
    submission.responses.each do |survey_response|
      survey_response.update!(
        understandable_rating: 5,
        possible_rating: 4,
        relevant_rating: 6
      )
    end
    submission.finalize!
    submission.update_columns(finalized_at: 31.days.ago)

    get organization_assignment_survey_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include("less than 30 days ago")
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
    expect(response.body).to include("Results by assignment")
    expect(response.body).to include("Understandable")
    expect(response.body).to include("Possible")
    expect(response.body).to include("Relevant")
    expect(response.body).to include("data-bs-toggle=\"popover\"")
    expect(response.body).to include("make up these responses")
    expect(response.body).to include("represented")
    expect(response.body).to include("OG thinks this is Healthy.")
    expect(response.body).to include("OG thinks this is Strained.")
    expect(response.body).to include("OG thinks this is Incredible.")
    expect(response.body).to include("Small sample: only 1 response")
    expect(response.body).to include("assignment-survey-quality-healthy")
    expect(response.body).to include("assignment-survey-quality-strained")
    expect(response.body).to include("assignment-survey-quality-incredible")
    expect(response.body).to include("Sort by")
    expect(response.body).to include(results_organization_assignment_survey_path(organization, sort: "average"))
    expect(response.body).to include(results_organization_assignment_survey_path(organization, sort: "responses"))
    expect(response.body).to include(person.display_name)

    get results_organization_assignment_survey_path(organization, sort: "average")

    expect(response).to have_http_status(:success)
    expect(response.body).to include('aria-current="true"')
    expect(response.body).to include("Average")

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

  context "when signed in as a pure assignment maintainer" do
    let(:maintainer_person) { create(:person) }
    let(:maintainer) do
      create(:teammate, :assigned_employee, person: maintainer_person, organization: organization)
    end
    let(:assignment_with_scores) { create(:assignment, company: organization, title: "Maintained Role") }
    let(:other_rater) { create(:teammate, :assigned_employee, organization: organization) }

    before do
      create(:employment_tenure, company_teammate: maintainer, company: organization)
      create(:employment_tenure, company_teammate: other_rater, company: organization)
      create(:object_maintainer, maintainable: assignment_with_scores, company_teammate: maintainer)

      submission = create(:assignment_survey_submission, company_teammate: other_rater, organization: organization)
      create(
        :assignment_survey_response,
        submission: submission,
        assignment: assignment_with_scores,
        snapshot_title: assignment_with_scores.title,
        understandable_rating: 6,
        possible_rating: 5,
        relevant_rating: 4
      )
      submission.finalize!

      sign_in_as_teammate_for_request(maintainer_person, organization)
    end

    it "shows org-wide assignment score cards without individual people from outside hierarchy" do
      get results_organization_assignment_survey_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Results by assignment")
      expect(response.body).to include("Maintained Role")
      expect(response.body).to include("Org-wide (maintainer)")
      expect(response.body).not_to include("View responses")
      expect(response.body).not_to include(other_rater.person.display_name)
    end
  end
end
