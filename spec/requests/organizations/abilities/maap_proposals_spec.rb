# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Abilities::MaapProposals", type: :request do
  let(:organization) { create(:organization) }
  let(:ability) do
    create(
      :ability,
      company: organization,
      name: "Facilitation",
      description: "Help groups decide",
      milestone_1_description: "Can facilitate with a guide"
    )
  end
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

    it "lists proposals for the ability" do
      get organization_ability_maap_proposals_path(organization, ability)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(ability.name)
      expect(response.body).to include("Propose edit")
      expect(response.body).to include("abilityMaapProposalsPageHelp")
      expect(response.body).to include("Download markdown template")
      expect(response.body).to include("ability_proposal_status_draft")
    end
  end

  describe "proposal lifecycle" do
    it "lets a teammate draft and submit, and a MAAP manager apply" do
      sign_in_as_teammate_for_request(person, organization)
      get new_organization_ability_maap_proposal_path(organization, ability)
      expect(response).to redirect_to(%r{/maap_proposals/\d+/edit})

      proposal = ability.maap_proposals.order(:id).last
      patch organization_ability_maap_proposal_path(organization, ability, proposal), params: {
        maap_proposal: {
          name: "Facilitation+",
          description: "Help groups decide better",
          department_id: "",
          milestone_1_description: "Can facilitate with a guide",
          milestone_2_description: "Can facilitate independently",
          milestone_3_description: "",
          milestone_4_description: "",
          milestone_5_description: ""
        }
      }
      expect(response).to redirect_to(organization_ability_maap_proposal_path(organization, ability, proposal))

      post submit_organization_ability_maap_proposal_path(organization, ability, proposal)
      expect(proposal.reload).to be_submitted

      sign_in_as_teammate_for_request(manager, organization)
      post apply_organization_ability_maap_proposal_path(organization, ability, proposal), params: {
        version_type: "clarifying",
        decision_note: "Nice"
      }

      expect(response).to redirect_to(organization_ability_path(organization, ability))
      expect(proposal.reload).to be_applied
      expect(ability.reload.name).to eq("Facilitation+")
      expect(ability.milestone_2_description).to include("independently")
      expect(ability.semantic_version).to eq("1.1.0")
    end
  end

  describe "GET ability show" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "surfaces suggest edit and proposed edits entry points" do
      get organization_ability_path(organization, ability)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Suggest Edit")
      expect(response.body).to include("Propose edit")
      expect(response.body).to include(organization_ability_maap_proposals_path(organization, ability))
    end
  end
end
