# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::MaapAbilityCreates", type: :request do
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
      get organization_maap_ability_creates_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Proposed Ability creates")
      expect(response.body).to include("Propose new Ability")
      expect(response.body).to include("maapAbilityCreatesPageHelp")
      expect(response.body).to include("Download markdown template")
      expect(response.body).to include("ability_create_proposal_status_draft")
      expect(response.body).to include("ability_create_proposal_status_submitted")
    end
  end

  describe "create lifecycle" do
    it "lets anyone draft/submit and a creator apply with duplicate name suffix" do
      create(:ability, company: organization, name: "Facilitation")

      sign_in_as_teammate_for_request(person, organization)
      get new_organization_maap_ability_create_path(organization)
      expect(response).to redirect_to(%r{/maap_ability_creates/\d+/edit})

      proposal = MaapProposal.ability_creates.order(:id).last
      patch organization_maap_ability_create_path(organization, proposal), params: {
        maap_proposal: {
          name: "Facilitation",
          description: "Help groups move",
          department_id: "",
          milestone_1_description: "Can facilitate with guidance",
          milestone_2_description: "",
          milestone_3_description: "",
          milestone_4_description: "",
          milestone_5_description: ""
        }
      }
      expect(response).to redirect_to(organization_maap_ability_create_path(organization, proposal))

      post submit_organization_maap_ability_create_path(organization, proposal)
      expect(response).to redirect_to(organization_maap_ability_create_path(organization, proposal))
      expect(proposal.reload).to be_submitted

      get organization_maap_ability_create_path(organization, proposal)
      expect(response.body).to include("(duplicate)")
      expect(response.body).to include("Apply proposal")

      sign_in_as_teammate_for_request(manager, organization)
      post apply_organization_maap_ability_create_path(organization, proposal), params: {
        decision_note: "Looks good"
      }

      proposal.reload
      expect(proposal).to be_applied
      expect(proposal.proposable).to be_a(Ability)
      expect(proposal.proposable.name).to eq("Facilitation (duplicate)")
      expect(proposal.proposable.semantic_version).to eq("0.0.1")
      expect(response).to redirect_to(organization_ability_path(organization, proposal.proposable))
    end
  end

  describe "GET abilities index" do
    it "links suggest new as primary for teammates without create access" do
      sign_in_as_teammate_for_request(person, organization)
      get organization_abilities_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('aria-label="Suggest New Ability"')
      expect(response.body).to include("Create New Ability")
      expect(response.body).to include("Suggest New Ability")
      expect(response.body).to include("View Suggested New Abilities")
      expect(response.body).to include(organization_maap_ability_creates_path(organization))
    end

    it "links create new as primary for teammates with create access" do
      sign_in_as_teammate_for_request(manager, organization)
      get organization_abilities_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('aria-label="Create New Ability"')
      expect(response.body).to include(new_organization_ability_path(organization))
      expect(response.body).to include("View Suggested New Abilities")
    end
  end
end
