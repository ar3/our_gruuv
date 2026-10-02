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

  describe "GET edit" do
    before { sign_in_as_teammate_for_request(person, organization) }

    it "renders the draft edit form with primary and additional titles" do
      department = create(:department, company: organization, name: "Engineering")
      extra_title = create(
        :title,
        company: organization,
        department: department,
        external_title: "Staff Engineer"
      )
      result = MaapProposals::CreateSeatEditDraft.call(seat: seat, proposer: person_teammate)
      proposal = result.value

      get edit_organization_seat_maap_proposal_path(organization, seat, proposal)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit draft proposal")
      expect(response.body).to include("Primary Title")
      expect(response.body).to include("Additional Titles")
      expect(response.body).to include(title.external_title)
      expect(response.body).to include(extra_title.external_title)
      expect(response.body).to include("optgroup")
      expect(response.body).to match(/optgroup label="[^"]*Engineering/)
      expect(response.body).to include("Needed By Date")
      expect(response.body).to include("Save draft")
      expect(response.body).to include(organization_seat_maap_proposal_path(organization, seat, proposal))
    end
  end

  describe "proposal lifecycle" do
    it "lets a teammate draft and submit, and a MAAP manager apply" do
      extra_title = create(:title, company: organization, external_title: "Staff Engineer")
      sign_in_as_teammate_for_request(person, organization)
      get new_organization_seat_maap_proposal_path(organization, seat)
      expect(response).to redirect_to(%r{/maap_proposals/\d+/edit})

      proposal = seat.maap_proposals.order(:id).last
      patch organization_seat_maap_proposal_path(organization, seat, proposal), params: {
        maap_proposal: {
          title_id: title.id,
          additional_title_ids: [extra_title.id],
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
      expect(seat.associated_title_ids).to contain_exactly(title.id, extra_title.id)
    end
  end

  describe "GET seat show" do
    it "surfaces suggest edit and proposed edits for any teammate" do
      sign_in_as_teammate_for_request(person, organization)
      get organization_seat_path(organization, seat)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Suggest Edit")
      expect(response.body).to include("proposed edits")
      expect(response.body).to include(organization_seat_maap_proposals_path(organization, seat))
      expect(response.body).to include("Archive")
      expect(response.body).not_to include("bi-trash")
    end

    it "links Archive for MAAP managers" do
      sign_in_as_teammate_for_request(manager, organization)
      get organization_seat_path(organization, seat)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(archive_organization_seat_path(organization, seat))
      expect(response.body).to include("Archive")
    end
  end
end
