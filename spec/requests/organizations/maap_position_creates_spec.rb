# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::MaapPositionCreates", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:title) { create(:title, company: organization, external_title: "Engineer") }
  let!(:person_teammate) { create(:teammate, :unassigned_employee, person: person, organization: organization) }

  before do
    PaperTrail.enabled = false
    sign_in_as_teammate_for_request(person, organization)
  end

  after { PaperTrail.enabled = true }

  describe "GET index" do
    it "lists Position create proposals and page help" do
      create(
        :maap_proposal,
        :position_create,
        :submitted,
        organization: organization,
        proposer: person_teammate,
        proposed_payload: MaapProposals::PositionPayload.from_hash(
          "title_id" => title.id,
          "position_summary" => "Level-one engineering seat shape",
          "position_level_hint" => "1"
        ).to_h
      )

      get organization_maap_position_creates_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Proposed Position creates")
      expect(response.body).to include("maapPositionCreatesPageHelp")
      expect(response.body).to include("Engineer")
      expect(response.body).to include("position_create_proposal_status_draft")
      expect(response.body).to include("Suggest MAAP changes")
      expect(response.body).to include(organization_seat_suggestion_path(organization))
    end
  end

  describe "GET show" do
    it "renders the Position create proposal" do
      proposal = create(
        :maap_proposal,
        :position_create,
        organization: organization,
        proposer: person_teammate,
        proposed_payload: MaapProposals::PositionPayload.from_hash(
          "title_id" => title.id,
          "position_summary" => "Show position summary",
          "position_level_hint" => "1"
        ).to_h
      )

      get organization_maap_position_create_path(organization, proposal)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Position create proposal")
      expect(response.body).to include("Show position summary")
      expect(response.body).to include(organization_maap_position_creates_path(organization))
    end
  end
end
