# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Titles::MaapProposals", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let!(:title) { create(:title, company: organization, external_title: "Engineer") }
  let!(:person_teammate) { create(:teammate, :unassigned_employee, person: person, organization: organization) }
  let!(:manager_teammate) do
    create(:teammate, :unassigned_employee, :maap_manager, person: manager, organization: organization)
  end
  let!(:person_tenure) do
    create(:employment_tenure, teammate: person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  describe "GET title show entry points" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "links Suggest Edit and proposed edits from the title view switcher" do
      get organization_title_path(organization, title)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Suggest Edit")
      expect(response.body).to include(new_organization_title_maap_proposal_path(organization, title))
      expect(response.body).to include("Proposed edits")
      expect(response.body).to include(organization_title_maap_proposals_path(organization, title))
    end
  end

  describe "GET index" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "lists proposals for the title with page help and propose CTA" do
      get organization_title_maap_proposals_path(organization, title)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Proposed Title edits")
      expect(response.body).to include("titleMaapProposalsPageHelp")
      expect(response.body).to include(new_organization_title_maap_proposal_path(organization, title))
      expect(response.body).to include("title_proposal_status_draft")
    end
  end

  describe "edit lifecycle" do
    it "lets anyone draft/submit and a title updater apply" do
      sign_in_as_teammate_for_request(person, organization)
      get new_organization_title_maap_proposal_path(organization, title)
      expect(response).to redirect_to(%r{/titles/.+/maap_proposals/\d+/edit})

      proposal = MaapProposal.for_proposable(title).order(:id).last
      patch organization_title_maap_proposal_path(organization, title, proposal), params: {
        maap_proposal: {
          external_title: "Staff Engineer",
          position_major_level_id: title.position_major_level_id,
          department_id: title.department_id,
          position_summary: "Platform focus",
          alternative_titles: title.alternative_titles
        }
      }
      expect(response).to redirect_to(organization_title_maap_proposal_path(organization, title, proposal))

      post submit_organization_title_maap_proposal_path(organization, title, proposal)
      expect(response).to redirect_to(organization_title_maap_proposal_path(organization, title, proposal))
      expect(proposal.reload).to be_submitted

      get organization_title_maap_proposal_path(organization, title, proposal)
      expect(response.body).to include("Staff Engineer")
      expect(response.body).to include("Waiting for someone who can update Titles")

      sign_in_as_teammate_for_request(manager, organization)
      get organization_title_maap_proposal_path(organization, title, proposal)
      expect(response.body).to include("Apply proposal")

      post apply_organization_title_maap_proposal_path(organization, title, proposal), params: {
        decision_note: "Approved"
      }

      expect(response).to redirect_to(organization_title_path(organization, title))
      expect(proposal.reload).to be_applied
      expect(title.reload.external_title).to eq("Staff Engineer")
    end
  end
end
