# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::SeatSuggestions", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/seat_suggestion" do
    it "renders the beta Suggest a Seat chat page" do
      get organization_seat_suggestion_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Suggest a Seat")
      expect(response.body).to include("Beta")
      expect(response.body).to include("Paste whatever you have")
      expect(response.body).to include("ask-og")
      expect(response.body).to include("Start new conversation")
      expect(response.body).to include("⌘/Ctrl+Enter to send")
      expect(response.body).to include(page_help_id_fragment)
      expect(response.body).to include(organization_seat_suggestions_path(organization))
      expect(response.body).to include(organization_seat_suggestion_path(organization))
    end

    it "shows user-facing conversation status instead of failed/completed" do
      consultation = OgConsultation.create!(
        kind: OgConsultation::KIND_SEAT_SUGGESTION,
        subject: organization,
        organization: organization,
        triggered_by_teammate: teammate,
        status: "completed",
        billable: true,
        units_total: 1,
        units_completed: 1,
        completed_at: Time.current
      )
      AskOgResult.create!(
        og_consultation: consultation,
        query: "Franchise Partner Success Manager seat",
        proposed_actions: [
          {
            "tool" => "create_seat_suggestion_bundle",
            "label" => "Create Seat proposal drafts",
            "summary" => "Create drafts",
            "args" => {}
          }
        ]
      )
      consultation.update!(result: consultation.ask_og_result)

      get organization_seat_suggestion_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Draft being reviewed")
      expect(response.body).not_to include(">completed<")
      expect(response.body).not_to include(">failed<")
    end
  end

  describe "POST /organizations/:organization_id/seat_suggestions" do
    it "starts a seat_suggestion consultation and enqueues AskOgJob" do
      expect {
        post organization_seat_suggestions_path(organization), params: { q: "We need a Staff Data Analytics Engineer" }
      }.to have_enqueued_job(AskOgJob)

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["ok"]).to eq(true)
      consultation = OgConsultation.find(body["consultation_id"])
      expect(consultation.kind).to eq(OgConsultation::KIND_SEAT_SUGGESTION)
      expect(consultation.billable).to eq(true)
      expect(consultation.result).to be_a(AskOgResult)
      expect(consultation.result.query).to include("Staff Data Analytics Engineer")
    end
  end

  def page_help_id_fragment
    "seatSuggestionPageHelp"
  end
end
