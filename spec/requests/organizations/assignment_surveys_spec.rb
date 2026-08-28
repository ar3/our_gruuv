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

  it "renders the beta survey and opens the feedback form" do
    get organization_assignment_survey_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Assignment Experience Survey")
    expect(response.body).to include("Beta")
    expect(response.body).to include("This feedback is identifiable")
    expect(teammate.assignment_survey_responses.in_progress.pluck(:assignment_id)).to eq([ assignment.id ])
  end

  it "autosaves and submits filled feedback (including a subset)" do
    survey_response = AssignmentSurveys::ResponseWorkspace.new(
      organization: organization,
      teammate: teammate
    ).call.first
    response_params = {
      "0" => {
        id: survey_response.id,
        understandable_rating: 5,
        possible_rating: 4,
        relevant_rating: 6,
        personal_alignment: "like",
        comment: "Clear and useful"
      }
    }

    patch organization_assignment_survey_path(organization),
          params: {
            autosave: "1",
            assignment_survey_responses: response_params
          },
          headers: { "ACCEPT" => "application/json" }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include("ok" => true)
    expect(survey_response.reload.comment).to eq("Clear and useful")
    expect(survey_response.personal_alignment).to eq("like")

    patch organization_assignment_survey_path(organization),
          params: {
            finalize: "1",
            assignment_survey_responses: response_params
          }

    expect(response).to redirect_to(organization_assignment_survey_path(organization))
    expect(teammate.assignment_survey_responses.submitted).to exist
    expect(teammate.assignment_survey_responses.in_progress).not_to exist
  end

  it "rejects submit when nothing has content" do
    AssignmentSurveys::ResponseWorkspace.new(organization: organization, teammate: teammate).call

    patch organization_assignment_survey_path(organization),
          params: { finalize: "1" }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Add feedback on at least one assignment")
    expect(teammate.assignment_survey_responses.in_progress).to exist
  end

  it "clears in-progress responses" do
    AssignmentSurveys::ResponseWorkspace.new(organization: organization, teammate: teammate).call

    delete organization_assignment_survey_path(organization)

    expect(response).to redirect_to(organization_assignment_survey_path(organization))
    expect(teammate.assignment_survey_responses.in_progress).not_to exist
  end

  it "shows due messaging and opens the feedback form directly" do
    survey_response = AssignmentSurveys::ResponseWorkspace.new(
      organization: organization,
      teammate: teammate
    ).call.first
    survey_response.update!(
      understandable_rating: 5,
      possible_rating: 4,
      relevant_rating: 6
    )
    survey_response.submit!

    get organization_assignment_survey_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("After each assignment check-in")
    expect(response.body).not_to include("Start or update feedback")
    expect(response.body).to include("Submit filled feedback").or include("Submit feedback")
    expect(response.body).to include("Click here to give feedback early")
    expect(response.body).to include("Your feedback is up to date")
    expect(response.body).to include("collapse show fresh-feedback-toggle-#{assignment.id}")
  end

  it "shows the feedback form when fresh feedback already has unsaved content" do
    survey_response = AssignmentSurveys::ResponseWorkspace.new(
      organization: organization,
      teammate: teammate
    ).call.first
    survey_response.update!(
      understandable_rating: 5,
      possible_rating: 4,
      relevant_rating: 6
    )
    survey_response.submit!

    in_progress = AssignmentSurveys::ResponseWorkspace.new(
      organization: organization,
      teammate: teammate
    ).call.first
    in_progress.update!(understandable_rating: 4)

    get organization_assignment_survey_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include("Click here to give feedback early")
    expect(response.body).to include("Feedback fresh")
  end

  it "opens directly to one assignment when assignment_id is present" do
    get organization_assignment_survey_path(organization, assignment_id: assignment.id)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Submit and stay here")
    expect(response.body).to include("Submit and go to assignment page")
    expect(response.body).to include("Submit and fill out other surveys")
    expect(response.body).to include("assignment-survey-response-#{assignment.id}")
  end

  it "redirects after single-assignment submit based on finalize_after" do
    survey_response = AssignmentSurveys::ResponseWorkspace.new(
      organization: organization,
      teammate: teammate,
      assignment_ids: [ assignment.id ]
    ).call.first
    response_params = {
      "0" => {
        id: survey_response.id,
        understandable_rating: 5,
        possible_rating: 4,
        relevant_rating: 6
      }
    }
    base_params = {
      assignment_id: assignment.id,
      response_ids: [ survey_response.id ],
      assignment_survey_responses: response_params
    }

    patch organization_assignment_survey_path(organization, assignment_id: assignment.id),
          params: base_params.merge(finalize_after: "stay")
    expect(response).to redirect_to(
      organization_assignment_survey_path(organization, assignment_id: assignment.id, anchor: "assignment-survey-response-#{assignment.id}")
    )

    survey_response = AssignmentSurveys::ResponseWorkspace.new(
      organization: organization,
      teammate: teammate,
      assignment_ids: [ assignment.id ]
    ).call.first
    response_params["0"][:id] = survey_response.id
    base_params[:response_ids] = [ survey_response.id ]

    patch organization_assignment_survey_path(organization, assignment_id: assignment.id),
          params: base_params.merge(finalize_after: "assignment")
    expect(response).to redirect_to(organization_assignment_path(organization, assignment.id))

    survey_response = AssignmentSurveys::ResponseWorkspace.new(
      organization: organization,
      teammate: teammate,
      assignment_ids: [ assignment.id ]
    ).call.first
    response_params["0"][:id] = survey_response.id
    base_params[:response_ids] = [ survey_response.id ]

    patch organization_assignment_survey_path(organization, assignment_id: assignment.id),
          params: base_params.merge(finalize_after: "others")
    expect(response).to redirect_to(organization_assignment_survey_path(organization))
  end

  it "shows results and exports CSV" do
    survey_response = AssignmentSurveys::ResponseWorkspace.new(
      organization: organization,
      teammate: teammate
    ).call.first
    survey_response.update!(
      understandable_rating: 5,
      possible_rating: 4,
      relevant_rating: 6,
      personal_alignment: "love"
    )
    survey_response.submit!

    get results_organization_assignment_survey_path(organization)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Current overall results")
    expect(response.body).to include("Results by assignment")
    expect(response.body).to include("Understandable")
    expect(response.body).to include("Possible")
    expect(response.body).to include("Relevant")
    expect(response.body).to include("Personal alignment")
    expect(response.body).to include("Only If Necessary")
    expect(response.body).to include("just for this Assignment")
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
    expect(response.body).to include("Personal alignment")
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
      create(:assignment_survey_response, :partial, company_teammate: teammate, assignment: assignment)
      sign_in_as_teammate_for_request(manager_person, organization)
    end

    it "can see a report's in-progress status" do
      get results_organization_assignment_survey_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(person.display_name)
      expect(response.body).to include("In progress")
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

      create(
        :assignment_survey_response,
        :complete,
        company_teammate: other_rater,
        assignment: assignment_with_scores,
        snapshot_title: assignment_with_scores.title,
        understandable_rating: 6,
        possible_rating: 5,
        relevant_rating: 4
      )

      sign_in_as_teammate_for_request(maintainer_person, organization)
    end

    it "shows org-wide assignment score cards without individual people from outside hierarchy" do
      get results_organization_assignment_survey_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Results by assignment")
      expect(response.body).to include("Maintained Role")
      expect(response.body).to include("Org-wide (maintainer)")
      expect(response.body).not_to include(other_rater.person.display_name)
    end
  end
end
