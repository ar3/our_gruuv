# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teams Health", type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /organizations/:organization_id/teams_health" do
    it "returns success and shows Team Goal Confidence summary" do
      create(:team, company: company, name: "Alpha Squad")

      get organization_teams_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Teams Health")
      expect(response.body).to include("teamsHealthPageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Total Active Teams")
      expect(response.body).to include("Healthy")
      expect(response.body).to include("Warning")
      expect(response.body).to include("Needs Attention")
      expect(response.body).to include("Team-owned")
      expect(response.body).to include("Switch object")
      expect(response.body).to include("Switch page type")
      expect(response.body).to include(organization_teams_path(company))
      expect(response.body).to include(organization_insights_teams_path(company))
      expect(response.body).to include("health-dashboard-toolbar")
    end
  end
end
