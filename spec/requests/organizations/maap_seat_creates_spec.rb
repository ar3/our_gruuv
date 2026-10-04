# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::MaapSeatCreates", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let!(:title) { create(:title, company: organization, external_title: "Engineer") }
  let!(:person_teammate) { create(:teammate, :unassigned_employee, person: person, organization: organization) }
  let!(:manager_teammate) do
    create(:teammate, :unassigned_employee, :maap_manager, person: manager, organization: organization)
  end

  before { PaperTrail.enabled = false }
  after { PaperTrail.enabled = true }

  describe "GET index" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "lists create proposals and page help" do
      get organization_maap_seat_creates_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Proposed Seat creates")
      expect(response.body).to include("Suggest a Seat")
      expect(response.body).to include(organization_seat_suggestion_path(organization))
      expect(response.body).to include("Propose new Seat")
      expect(response.body).to include("maapSeatCreatesPageHelp")
      expect(response.body).to include("Download markdown template")
      expect(response.body).to include("seat_create_proposal_status_draft")
    end
  end

  describe "GET edit" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "renders the create draft form with primary and additional titles" do
      department = create(:department, company: organization, name: "Engineering")
      extra_title = create(
        :title,
        company: organization,
        department: department,
        external_title: "Staff Engineer"
      )
      result = MaapProposals::CreateSeatCreateDraft.call(
        organization: organization,
        proposer: person_teammate
      )
      proposal = result.value

      get edit_organization_maap_seat_create_path(organization, proposal)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit draft Seat create proposal")
      expect(response.body).to include("Primary Title")
      expect(response.body).to include("Additional Titles")
      expect(response.body).to include(title.external_title)
      expect(response.body).to include(extra_title.external_title)
      expect(response.body).to include("optgroup")
      expect(response.body).to match(/optgroup label="[^"]*Engineering/)
      expect(response.body).to include("Save draft")
    end
  end

  describe "create lifecycle" do
    it "lets anyone draft/submit and a creator apply" do
      sign_in_as_teammate_for_request(person, organization)
      get new_organization_maap_seat_create_path(organization)
      expect(response).to redirect_to(%r{/maap_seat_creates/\d+/edit})

      proposal = MaapProposal.seat_creates.order(:id).last
      patch organization_maap_seat_create_path(organization, proposal), params: {
        maap_proposal: {
          title_id: title.id,
          additional_title_ids: [],
          seat_needed_by: (Date.current + 2.months).iso8601,
          job_classification: "Salaried Exempt",
          why_needed: "Need capacity"
        }
      }
      expect(response).to redirect_to(organization_maap_seat_create_path(organization, proposal))

      post submit_organization_maap_seat_create_path(organization, proposal)
      expect(response).to redirect_to(organization_maap_seat_create_path(organization, proposal))
      expect(proposal.reload).to be_submitted

      get organization_maap_seat_create_path(organization, proposal)
      expect(response.body).to include("Apply proposal")
      expect(response.body).to include("Need capacity")

      sign_in_as_teammate_for_request(manager, organization)
      post apply_organization_maap_seat_create_path(organization, proposal), params: {
        decision_note: "Approved"
      }

      proposal.reload
      expect(proposal).to be_applied
      expect(proposal.proposable).to be_a(Seat)
      expect(proposal.proposable).to be_draft
      expect(response).to redirect_to(organization_seat_path(organization, proposal.proposable))
    end
  end

  describe "GET seats index" do
    it "links suggest new seat for teammates without create access" do
      sign_in_as_teammate_for_request(person, organization)
      get organization_seats_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Suggest New Seat")
      expect(response.body).to include(new_organization_maap_seat_create_path(organization))
      expect(response.body).to include("View Suggested New Seats")
      expect(response.body).to include("Filled only")
      expect(response.body).to include("Unfilled only")
      expect(response.body).to include("All Open")
      expect(response.body).to include("Draft only")
    end
  end
end
