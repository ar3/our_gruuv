# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Seats::MaapProposals", type: :request do
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization, external_title: "Engineer") }
  let(:seat) do
    create(
      :seat,
      title: title,
      seat_needed_by: Date.current + 2.months,
      job_classification: "Salaried Exempt",
      why_needed: "Need capacity"
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

    it "lists proposals for the seat" do
      get organization_seat_maap_proposals_path(organization, seat)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(seat.display_name)
      expect(response.body).to include("Propose edit")
      expect(response.body).to include("seatMaapProposalsPageHelp")
      expect(response.body).to include("Download markdown template")
      expect(response.body).to include("seat_proposal_status_draft")
    end
  end

  describe "proposal lifecycle" do
    it "lets a teammate draft and submit, and a MAAP manager apply" do
      sign_in_as_teammate_for_request(person, organization)
      get new_organization_seat_maap_proposal_path(organization, seat)
      expect(response).to redirect_to(%r{/maap_proposals/\d+/edit})

      proposal = seat.maap_proposals.order(:id).last
      patch organization_seat_maap_proposal_path(organization, seat, proposal), params: {
        maap_proposal: {
          title_id: title.id,
          seat_needed_by: (Date.current + 3.months).iso8601,
          job_classification: "Hourly",
          team_id: "",
          reports_to_seat_id: "",
          reports: "One junior",
          why_needed: "Need more capacity",
          why_now: "Pipeline grew",
          costs_risks: "Miss deadlines",
          seat_disclaimer: "",
          work_environment: "",
          physical_requirements: "",
          travel: ""
        }
      }
      expect(response).to redirect_to(organization_seat_maap_proposal_path(organization, seat, proposal))

      post submit_organization_seat_maap_proposal_path(organization, seat, proposal)
      expect(proposal.reload).to be_submitted

      sign_in_as_teammate_for_request(manager, organization)
      post apply_organization_seat_maap_proposal_path(organization, seat, proposal), params: {
        decision_note: "Looks good"
      }

      expect(response).to redirect_to(organization_seat_path(organization, seat))
      expect(proposal.reload).to be_applied
      expect(seat.reload.job_classification).to eq("Hourly")
      expect(seat.why_needed).to eq("Need more capacity")
      expect(seat.reports).to eq("One junior")
    end
  end

  describe "GET seat show" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "surfaces suggest edit and proposed edits entry points" do
      get organization_seat_path(organization, seat)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Suggest Edit")
      expect(response.body).to include("proposed edits")
      expect(response.body).to include(organization_seat_maap_proposals_path(organization, seat))
      expect(response.body).to include("Delete")
    end
  end
end
