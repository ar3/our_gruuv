# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Positions::MaapProposals", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) do
    title.position_major_level.position_levels.first ||
      create(:position_level, position_major_level: title.position_major_level, level: "1.1")
  end
  let!(:position) { create(:position, title: title, position_level: position_level, position_summary: "Baseline") }
  let!(:assignment) { create(:assignment, company: organization, title: "Ship features") }
  let!(:person_teammate) { create(:teammate, :unassigned_employee, person: person, organization: organization) }
  let!(:manager_teammate) do
    create(:teammate, :unassigned_employee, :maap_manager, person: manager, organization: organization)
  end

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  describe "GET position show entry points" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "links Suggest Edit and proposed edits from the view switcher" do
      get organization_position_path(organization, position)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Suggest Edit")
      expect(response.body).to include(new_organization_position_maap_proposal_path(organization, position))
      expect(response.body).to include("Proposed edits")
      expect(response.body).to include(organization_position_maap_proposals_path(organization, position))
    end
  end

  describe "GET index" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "lists proposals for the position with page help and propose CTA" do
      get organization_position_maap_proposals_path(organization, position)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Proposed Position edits")
      expect(response.body).to include("positionMaapProposalsPageHelp")
      expect(response.body).to include(new_organization_position_maap_proposal_path(organization, position))
      expect(response.body).to include("position_proposal_status_draft")
    end
  end

  describe "edit lifecycle" do
    it "lets anyone draft/submit and a position updater apply" do
      sign_in_as_teammate_for_request(person, organization)
      get new_organization_position_maap_proposal_path(organization, position)
      expect(response).to redirect_to(%r{/positions/.+/maap_proposals/\d+/edit})

      proposal = MaapProposal.for_proposable(position).order(:id).last
      patch organization_position_maap_proposal_path(organization, position, proposal), params: {
        maap_proposal: {
          position_summary: "Platform focus",
          position_level_id: position.position_level_id,
          assignment_links: {
            "0" => {
              assignment_id: assignment.id,
              assignment_type: "required",
              energy_percentage: 35
            }
          }
        }
      }
      expect(response).to redirect_to(organization_position_maap_proposal_path(organization, position, proposal))

      post submit_organization_position_maap_proposal_path(organization, position, proposal)
      expect(response).to redirect_to(organization_position_maap_proposal_path(organization, position, proposal))
      expect(proposal.reload).to be_submitted

      get organization_position_maap_proposal_path(organization, position, proposal)
      expect(response.body).to include("Platform focus")
      expect(response.body).to include("Waiting for someone who can update Positions")

      sign_in_as_teammate_for_request(manager, organization)
      get organization_position_maap_proposal_path(organization, position, proposal)
      expect(response.body).to include("Apply proposal")

      post apply_organization_position_maap_proposal_path(organization, position, proposal), params: {
        decision_note: "Approved"
      }

      expect(response).to redirect_to(organization_position_path(organization, position))
      expect(proposal.reload).to be_applied
      expect(position.reload.position_summary).to eq("Platform focus")
      expect(position.position_assignments.map(&:assignment_id)).to eq([assignment.id])
    end
  end
end
