# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Job description acknowledgement", type: :request do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person, first_name: "Samantha", last_name: "Cartwright") }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization, first_employed_at: 1.year.ago) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:teammate, :employment_manager, person: manager, organization: organization, first_employed_at: 1.year.ago) }
  let(:peer) { create(:person) }
  let(:peer_teammate) { create(:teammate, person: peer, organization: organization, first_employed_at: 1.year.ago) }
  let(:held_assignment) { create(:assignment, company: organization, title: "Build Widget", tagline: "Ship the widget") }
  let(:missing_assignment) { create(:assignment, company: organization, title: "Review Widget") }
  let(:optional_assignment) { create(:assignment, company: organization, title: "Teach Workshop") }
  let(:ability) do
    create(
      :ability,
      company: organization,
      name: "Widget Craft",
      description: "Skill for making widgets.",
      milestone_2_description: "Builds widgets alone."
    )
  end

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    position = employee_teammate.employment_tenures.find_by!(ended_at: nil).position
    position.update!(position_summary: "Own the widget line.")
    create(:position_assignment, :required, position: position, assignment: held_assignment)
    create(:position_assignment, :required, position: position, assignment: missing_assignment)
    create(:assignment_ability, assignment: held_assignment, ability: ability, milestone_level: 2)
    create(:assignment_ability, assignment: missing_assignment, ability: ability, milestone_level: 2)
    create(:position_ability, position: position, ability: ability, milestone_level: 2)
    create(:assignment_outcome, assignment: held_assignment, description: "Widgets ship every week")
    create(:assignment_tenure, teammate: employee_teammate, assignment: held_assignment, anticipated_energy_percentage: 40, started_at: 1.month.ago)
    create(:assignment_tenure, teammate: employee_teammate, assignment: optional_assignment, anticipated_energy_percentage: 10, started_at: 1.month.ago)
  end

  describe "GET index" do
    it "shows the signed True JD switcher item, seat placeholders, and required abilities" do
      sign_in_as_teammate_for_request(employee, organization)

      get organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("True JD (signed)")
      expect(response.body).to include("True Job Description (signed)")
      expect(response.body).to include("True Job Description (JD) (signed view)")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("This job description needs to be signed.")
      expect(response.body).to include("Review and Sign the current JD below")
      expect(response.body).to include("#sign-current-jd")
      expect(response.body).to include("No signatures yet.")
      expect(response.body).to include("Sign job description")
      expect(response.body).to include("Samantha Cartwright")
      expect(response.body).to include(employee.government_first_then_last_display_name)
      expect(response.body).to include("Reports To:")
      expect(response.body).to include("Job Classification:")
      expect(response.body).to include("no seat defined… correct this in")
      expect(response.body).to include("Seat Management for Samantha C.")
      expect(response.body).to include(organization_teammate_position_path(organization, employee_teammate))
      expect(response.body).to include("Work environment:")
      expect(response.body).to include("Current source for Job Description HR fields")
      expect(response.body).to include("Seat can be configured for a teammate")
      expect(response.body).to include("Click to modify Samantha C.&#39;s seat")
      expect(response.body).to include('bi-chevron-down')
      expect(response.body).to include('bi-chevron-up')
      expect(response.body).to include("Build Widget")
      expect(response.body).to include(organization_teammate_assignment_path(organization, employee_teammate, held_assignment))
      expect(response.body).to include("40% of your energy")
      expect(response.body).to include("Widgets ship every week")
      expect(response.body).to include("advanced Widget Craft")
      expect(response.body).to include(organization_teammate_ability_path(organization, employee_teammate, ability))
      expect(response.body).to include("Review Widget")
      expect(response.body).to include(organization_teammate_assignment_path(organization, employee_teammate, missing_assignment))
      expect(response.body).to include("0% of your energy")
      expect(response.body).to include("They need to be taking on this assignment.")
      expect(response.body).to include("Teach Workshop")
      expect(response.body).to include(organization_teammate_assignment_path(organization, employee_teammate, optional_assignment))
      expect(response.body).to include("Required Abilities (skills, knowledge, and behaviors)")
      expect(response.body).to include("Skill for making widgets.")
      expect(response.body).to include("Milestone 2 (Advanced)")
      expect(response.body).to include("Builds widgets alone.")
      expect(response.body).to include("Assignments that require at least this milestone:")
      expect(response.body).to include("Also required directly by the position.")
      expect(response.body).to include("Additional Abilities required")
      expect(response.body).to include("Own the widget line.")
      expect(response.body).to include("No signatures yet.")
      expect(response.body).to include('bi-link-45deg')
    end

    it "lists prior signatures at the top with a green banner when recently signed enough" do
      tenure = employee_teammate.employment_tenures.find_by!(ended_at: nil)
      create(
        :position_check_in,
        :closed,
        teammate: employee_teammate,
        employment_tenure: tenure,
        official_check_in_completed_at: 10.days.ago
      )
      acknowledgement = JobDescriptionAcknowledgement.create!(
        company_teammate: employee_teammate,
        organization: organization,
        employment_tenure: tenure,
        position: tenure.position,
        typed_name: "Samantha Cartwright",
        signed_at: 5.days.ago,
        document_html: "<p>Frozen JD</p>",
        snapshot: { "position_name" => tenure.position.display_name }
      )

      sign_in_as_teammate_for_request(employee, organization)
      get organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("This job description has been signed recently enough.")
      expect(response.body).to include("Signed job descriptions")
      expect(response.body).to include("View signed JD")
      expect(response.body).to include(
        organization_company_teammate_job_description_acknowledgement_path(organization, employee_teammate, acknowledgement)
      )
      expect(response.body).to include("Review and Sign the current JD below")
      expect(response.body.index("Signed job descriptions")).to be < response.body.index("Required Assignments")
    end

    it "lets a manager view the page but not the sign form" do
      sign_in_as_teammate_for_request(manager, organization)

      get organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Build Widget")
      expect(response.body).to include("True JD (signed)")
      expect(response.body).not_to include("Sign job description")
    end

    it "does not let an unrelated teammate view the page" do
      sign_in_as_teammate_for_request(peer, organization)

      get organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate)

      expect(response).to have_http_status(:redirect)
    end

    it "links from the manager job description and hides that link from teammates who cannot open it" do
      sign_in_as_teammate_for_request(manager, organization)
      get complete_picture_organization_company_teammate_path(organization, employee_teammate)
      expect(response.body).to include("Acknowledge job description")
      expect(response.body).to include(organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate))

      sign_in_as_teammate_for_request(peer, organization)
      get true_jd_print_organization_company_teammate_path(organization, employee_teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Acknowledge job description")
    end
  end

  describe "POST create" do
    it "stores the page wording and keeps that wording after the live job description changes" do
      sign_in_as_teammate_for_request(employee, organization)

      expect {
        post organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate),
             params: { job_description_acknowledgement: { typed_name: "Samantha Cartwright" } },
             headers: { "HTTP_USER_AGENT" => "RSpec JD Signer/1.0" }
      }.to change(JobDescriptionAcknowledgement, :count).by(1)

      acknowledgement = JobDescriptionAcknowledgement.last
      expect(response).to redirect_to(
        organization_company_teammate_job_description_acknowledgement_path(organization, employee_teammate, acknowledgement)
      )
      expect(acknowledgement.typed_name).to eq("Samantha Cartwright")
      expect(acknowledgement.request_info).to include(
        "ip_address" => a_string_matching(/.+/),
        "user_agent" => "RSpec JD Signer/1.0",
        "timestamp" => a_string_matching(/.+/),
        "request_id" => a_string_matching(/.+/),
        "request_source" => "true_jd_signed_page"
      )
      expect(acknowledgement.snapshot["required_assignments"]).to include(
        hash_including("title" => "Review Widget", "energy_percentage" => 0, "missing" => true)
      )
      expect(acknowledgement.snapshot["seat"]["present"]).to eq(false)

      held_assignment.update!(title: "Assemble Gadget")

      get organization_company_teammate_job_description_acknowledgement_path(organization, employee_teammate, acknowledgement)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("True JD (signed)")
      expect(response.body).to include("View all previously signed job descriptions, or sign this job description again")
      expect(response.body).to include(organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate))
      expect(response.body).to include("Signature details")
      expect(response.body).to include("IP address:")
      expect(response.body).to include(acknowledgement.request_info["ip_address"])
      expect(response.body).to include("User agent:")
      expect(response.body).to include(acknowledgement.request_info["user_agent"])
      expect(response.body).to include("Request source:")
      expect(response.body).to include("true_jd_signed_page")
      expect(response.body).to include("Build Widget")
      expect(response.body).not_to include("Assemble Gadget")
      expect(response.body).to include("jd-signature-ink")
      expect(response.body).to include("Samantha Cartwright")

      get organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate)
      expect(response.body).to include("Assemble Gadget")
      expect(response.body).to include("Past signatures")
    end

    it "rejects a name that does not match the account" do
      employee.update!(preferred_name: "Sammy")
      sign_in_as_teammate_for_request(employee, organization)

      expect {
        post organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate),
             params: { job_description_acknowledgement: { typed_name: "Sammy Cartwright" } }
      }.not_to change(JobDescriptionAcknowledgement, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must match your full name")
      expect(response.body).to include(employee.government_first_then_last_display_name)
    end

    it "accepts the government first-then-last display name when a preferred name differs" do
      employee.update!(preferred_name: "Sammy")
      signed_name = employee.government_first_then_last_display_name
      sign_in_as_teammate_for_request(employee, organization)

      expect {
        post organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate),
             params: { job_description_acknowledgement: { typed_name: signed_name } }
      }.to change(JobDescriptionAcknowledgement, :count).by(1)

      expect(JobDescriptionAcknowledgement.last.typed_name).to eq(signed_name)
    end

    it "does not let a manager sign for the employee" do
      sign_in_as_teammate_for_request(manager, organization)

      expect {
        post organization_company_teammate_job_description_acknowledgements_path(organization, employee_teammate),
             params: { job_description_acknowledgement: { typed_name: "Samantha Cartwright" } }
      }.not_to change(JobDescriptionAcknowledgement, :count)

      expect(response).to have_http_status(:redirect)
    end
  end
end
