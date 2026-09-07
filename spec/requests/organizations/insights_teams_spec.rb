# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Insights Teams", type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /organizations/:organization_id/insights/teams" do
    it "returns success and shows team counts and activity chart" do
      create(:team, :with_members, company: company, member_count: 2)

      get organization_insights_teams_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Insights: Teams")
      expect(response.body).to include("Active teams")
      expect(response.body).to include("Average members per team")
      expect(response.body).to include("Team goals (week over week)")
      expect(response.body).to include("teams-goals-activity-chart")
      expect(response.body).to include("Switch object")
      expect(response.body).to include(organization_teams_path(company))
      expect(response.body).to include(organization_teams_health_path(company))
    end
  end
end
