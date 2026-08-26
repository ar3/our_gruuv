# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Milestones Health", type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil, can_manage_employment: true)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /organizations/:organization_id/milestones_health" do
    it "returns success and shows key sections" do
      get organization_milestones_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Milestones Health")
      expect(response.body).to include("milestonesHealthPageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Who to show")
      expect(response.body).to include("milestones-health-spotlight-full")
      expect(response.body).to include("Other actions")
      expect(response.body).to include("health-dashboard-toolbar")
      expect(response.body).to include("Gruuv Health")
      expect(response.body).to include("Switch object")
      expect(response.body).to include("Switch page type")
      expect(response.body).not_to include("Company Abilities Insights")
    end

    it "shows health dashboard switcher with links to other health pages" do
      get organization_milestones_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(organization_goals_health_path(company, manager_id: "everyone"))
      expect(response.body).to include(organization_check_ins_health_path(company, manager_id: "everyone"))
      expect(response.body).to include(organization_observations_health_path(company, manager_id: "everyone"))
    end
    it "shows a collapsed Milestones Health nudge panel for a concrete manager filter" do
      report_teammate = create(:teammate, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
      create(:employment_tenure, teammate: report_teammate, company: company, manager_teammate: teammate, started_at: 1.month.ago)

      get organization_milestones_health_path(company), params: { manager_id: "CompanyTeammate_#{teammate.id}" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Milestones Health, nudge for")
      expect(response.body).to include("healthNudge-milestones_health")
    end
  end

  describe "GET /organizations/:organization_id/milestones_health_employee_summary_export" do
    it "returns CSV attachment" do
      get organization_milestones_health_employee_summary_export_path(company)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end
  end

  describe "POST /organizations/:organization_id/milestones_health_refresh" do
    it "enqueues Gruuv Health refresh for the teammate" do
      expect {
        post organization_milestones_health_refresh_path(company), params: { teammate_id: teammate.id }
      }.to have_enqueued_job(EngagementHealthRefreshJob).with(teammate.id)
      expect(response).to redirect_to(organization_milestones_health_path(company))
    end
  end
end
