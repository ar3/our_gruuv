# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::MaapAssignmentCreates", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let!(:person_teammate) { create(:teammate, :unassigned_employee, person: person, organization: organization) }
  let!(:manager_teammate) do
    create(:teammate, :unassigned_employee, :maap_manager, person: manager, organization: organization)
  end

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  describe "GET index" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "lists create proposals and page help" do
      get organization_maap_assignment_creates_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Proposed Assignment creates")
      expect(response.body).to include("Propose new Assignment")
      expect(response.body).to include("maapAssignmentCreatesPageHelp")
      expect(response.body).to include("Download markdown template")
      expect(response.body).to include("create_proposal_status_draft")
      expect(response.body).to include("create_proposal_status_submitted")
    end
  end

  describe "create lifecycle" do
    it "lets anyone draft/submit and a creator apply with duplicate title suffix" do
      create(:assignment, company: organization, title: "Ops Lead")

      sign_in_as_teammate_for_request(person, organization)
      get new_organization_maap_assignment_create_path(organization)
      expect(response).to redirect_to(%r{/maap_assignment_creates/\d+/edit})

      proposal = MaapProposal.creates.order(:id).last
      patch organization_maap_assignment_create_path(organization, proposal), params: {
        maap_proposal: {
          title: "Ops Lead",
          tagline: "Run ops",
          required_activities: "Daily standup",
          handbook: "Keep calm",
          department_id: ""
        }
      }
      expect(response).to redirect_to(organization_maap_assignment_create_path(organization, proposal))

      post submit_organization_maap_assignment_create_path(organization, proposal)
      expect(response).to redirect_to(organization_maap_assignment_create_path(organization, proposal))
      expect(proposal.reload).to be_submitted

      get organization_maap_assignment_create_path(organization, proposal)
      expect(response.body).to include("(duplicate)")
      expect(response.body).to include("Apply proposal")

      sign_in_as_teammate_for_request(manager, organization)
      post apply_organization_maap_assignment_create_path(organization, proposal), params: {
        decision_note: "Looks good"
      }

      proposal.reload
      expect(proposal).to be_applied
      expect(proposal.proposable).to be_a(Assignment)
      expect(proposal.proposable.title).to eq("Ops Lead (duplicate)")
      expect(proposal.proposable.semantic_version).to eq("0.0.1")
      expect(response).to redirect_to(organization_assignment_path(organization, proposal.proposable))
    end
  end

  describe "GET assignments index" do
    it "links suggest new as primary for teammates without create access" do
      sign_in_as_teammate_for_request(person, organization)
      get organization_assignments_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('aria-label="Suggest New Assignment"')
      expect(response.body).to include("Create New Assignment")
      expect(response.body).to include("Suggest New Assignment")
      expect(response.body).to include("View Suggested New Assignments")
      expect(response.body).to include(organization_maap_assignment_creates_path(organization))
    end

    it "links create new as primary for teammates with create access" do
      sign_in_as_teammate_for_request(manager, organization)
      get organization_assignments_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('aria-label="Create New Assignment"')
      expect(response.body).to include(new_organization_assignment_path(organization))
      expect(response.body).to include("View Suggested New Assignments")
    end
  end
end
