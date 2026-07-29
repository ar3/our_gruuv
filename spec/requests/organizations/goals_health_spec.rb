# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Goals Health", type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil, can_manage_employment: true)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /organizations/:organization_id/goals_health" do
    it "returns success and shows key sections" do
      get organization_goals_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Goals Health")
      expect(response.body).to include("goalsHealthPageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Who to show")
      expect(response.body).to include("Goal Confidence")
      expect(response.body).to include("goals-health-spotlight-full")
      expect(response.body).to include("Warning")
      expect(response.body).to include("Needs Attention")
      expect(response.body).to include("Gruuv Health")
      expect(response.body).to include("Active:")
      expect(response.body).to include("Completed:")
      expect(response.body).to include("No active goals are attached")
      expect(response.body).to include("Drafts:")
      expect(response.body).to include("Other actions")
      expect(response.body).to include("health-dashboard-toolbar")
      expect(response.body).not_to include("Top-level & associated")
      expect(response.body).not_to include("data-bs-toggle=\"popover\"")
    end

    it "shows health dashboard switcher with links to check-ins and observations health" do
      get organization_goals_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(organization_check_ins_health_path(company, manager_id: "everyone"))
      expect(response.body).to include(organization_observations_health_path(company, manager_id: "everyone"))
    end

    it "uses aggregate counts that ignore privacy for table/spotlight data" do
      report_person = create(:person, first_name: "Report", last_name: "Employee")
      report_teammate = create(:teammate, person: report_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
      create(:employment_tenure, teammate: teammate, company: company, started_at: 2.months.ago)
      create(:employment_tenure, teammate: report_teammate, company: company, manager_teammate: teammate, started_at: 1.month.ago)

      goal = create(
        :goal,
        owner: report_teammate,
        creator: report_teammate,
        company: company,
        title: "Private report goal",
        privacy_level: "only_creator",
        started_at: 1.week.ago
      )
      EngagementHealthStatus.create!(
        teammate: report_teammate,
        organization: company,
        level: "category",
        category: EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
        status: EngagementHealth::WARNING,
        inputs: {},
        computed_at: Time.current
      )
      EngagementHealthStatus.create!(
        teammate: report_teammate,
        organization: company,
        level: "item",
        category: EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
        entity_type: "Goal",
        entity_id: goal.id,
        status: EngagementHealth::WARNING,
        inputs: { "goal_state" => "active", "name" => goal.title },
        computed_at: Time.current
      )

      get organization_goals_health_path(company), params: { manager_id: "my_direct_employees" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Report Employee")
      expect(response.body).to include("Total Active Employees")
      expect(response.body).to include("Active: 1")
      expect(response.body).to include("Warning")
    end
  end

  describe "GET /organizations/:organization_id/goals_health_export" do
    it "returns CSV attachment" do
      get organization_goals_health_export_path(company)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end
  end

  describe "GET /organizations/:organization_id/goals_health_employee_summary_export" do
    it "returns CSV attachment" do
      get organization_goals_health_employee_summary_export_path(company)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end
  end
end
