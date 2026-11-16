# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::MaapTitleCreates", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:person_teammate) { create(:teammate, :unassigned_employee, person: person, organization: organization) }

  before do
    PaperTrail.enabled = false
    sign_in_as_teammate_for_request(person, organization)
  end

  after { PaperTrail.enabled = true }

  describe "GET index" do
    it "lists Title create proposals and page help" do
      create(
        :maap_proposal,
        :title_create,
        :submitted,
        organization: organization,
        proposer: person_teammate,
        proposed_payload: MaapProposals::TitlePayload.blank_for_create(company: organization).to_h.merge(
          "external_title" => "Inbox Title"
        )
      )

      get organization_maap_title_creates_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Proposed Title creates")
      expect(response.body).to include("maapTitleCreatesPageHelp")
      expect(response.body).to include("Inbox Title")
      expect(response.body).to include("title_create_proposal_status_draft")
      expect(response.body).to include("Suggest MAAP changes")
      expect(response.body).to include(organization_seat_suggestion_path(organization))
    end
  end

  describe "GET show" do
    it "renders the Title create proposal" do
      proposal = create(
        :maap_proposal,
        :title_create,
        organization: organization,
        proposer: person_teammate,
        proposed_payload: MaapProposals::TitlePayload.blank_for_create(company: organization).to_h.merge(
          "external_title" => "Show Title"
        )
      )

      get organization_maap_title_create_path(organization, proposal)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Title create proposal")
      expect(response.body).to include("Show Title")
      expect(response.body).to include(organization_maap_title_creates_path(organization))
    end
  end
end
