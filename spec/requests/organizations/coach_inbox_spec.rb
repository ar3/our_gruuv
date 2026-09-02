# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Coach Inbox", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, :assigned_employee, person: person, organization: organization) }

  before do
    teammate
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/coach_inbox" do
    it "renders the beta inbox with four sections and coming-soon nudge" do
      get organization_coach_inbox_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Coach Inbox")
      expect(response.body).to include("Beta")
      expect(response.body).to include("Check-ins")
      expect(response.body).to include("OGOs")
      expect(response.body).to include("Goals")
      expect(response.body).to include("Expectation Alignment")
      expect(response.body).to include("Who to show")
      expect(response.body).to include("Coming soon")
      expect(response.body).to include("Show")
    end

    it "expands a sub-section to show item rows" do
      get organization_coach_inbox_path(organization, expand: ["open_feedback_responses"])

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Hide")
      expect(response.body).to include("No outstanding items in this sub-section")
    end

    it "is linked from Beta navigation" do
      get organization_start_here_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(organization_coach_inbox_path(organization))
      expect(response.body).to include("Coach Inbox")
    end
  end
end
