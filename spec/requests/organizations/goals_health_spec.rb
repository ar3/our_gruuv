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

    it "shows object/lens header switchers for Goals Health" do
      get organization_goals_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Switch object")
      expect(response.body).to include("Switch page type")
      expect(response.body).to include(organization_goals_path(company))
      expect(response.body).to include(organization_insights_goals_path(company))
      expect(response.body).to include(organization_sitemap_path(company))
      expect(response.body).not_to include('aria-label="Health dashboards"')
    end

    it "hides the Goals Health nudge panel unless a concrete manager is selected" do
      get organization_goals_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Goals Health nudge")
      expect(response.body).not_to include("goalsHealthNudge")
    end

    it "shows a collapsed Goals Health nudge panel for a concrete manager filter" do
      report_person = create(:person, first_name: "Report", last_name: "Employee")
      report_teammate = create(:teammate, person: report_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
      create(:employment_tenure, teammate: teammate, company: company, started_at: 2.months.ago)
      create(:employment_tenure, teammate: report_teammate, company: company, manager_teammate: teammate, started_at: 1.month.ago)

      get organization_goals_health_path(company), params: { manager_id: "CompanyTeammate_#{teammate.id}" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Goals Health nudge")
      expect(response.body).to include("goalsHealthNudge")
      expect(response.body).to include("Message preview")
      expect(response.body).to include("Send nudge now")
      expect(response.body).to include("Sends to")
      expect(response.body).to include('aria-expanded="false"')
      expect(response.body).to include("collapse")
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

  describe "POST /organizations/:organization_id/goals_health_nudge" do
    let(:company) { create(:organization, :company, :with_slack_config) }
    let(:manager_person) { create(:person, first_name: "Mgr", last_name: "One") }
    let(:manager_teammate) do
      create(:teammate, person: manager_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
    end
    let(:report_teammate) do
      create(:teammate, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
    end

    before do
      create(:employment_tenure, teammate: teammate, company: company, started_at: 2.months.ago)
      create(:employment_tenure, teammate: manager_teammate, company: company, manager_teammate: teammate, started_at: 2.months.ago)
      create(:employment_tenure, teammate: report_teammate, company: company, manager_teammate: manager_teammate, started_at: 1.month.ago)
      create(:teammate_identity, :slack, teammate: teammate, uid: "U_VIEWER")
      create(:teammate_identity, :slack, teammate: manager_teammate, uid: "U_MGR")
    end

    it "sends a nudge and redirects with notice" do
      slack_service = instance_double(SlackService)
      allow(SlackService).to receive(:new).with(company).and_return(slack_service)
      allow(slack_service).to receive(:open_or_create_group_dm)
        .and_return({ success: true, channel_id: "G123" })
      allow(slack_service).to receive(:post_message) do |notification_id|
        Notification.find(notification_id).update!(status: "sent_successfully", message_id: "9.9")
        { success: true, message_id: "9.9" }
      end

      expect do
        post organization_goals_health_nudge_path(company),
             params: { manager_id: "CompanyTeammate_#{manager_teammate.id}" }
      end.to change(Notification.where(notification_type: "goals_health_nudge"), :count).by(1)

      expect(response).to redirect_to(
        organization_goals_health_path(company, manager_id: "CompanyTeammate_#{manager_teammate.id}")
      )
      expect(flash[:notice]).to eq("Goals Health nudge sent.")
    end

    it "rejects non-concrete manager filters" do
      post organization_goals_health_nudge_path(company), params: { manager_id: "everyone" }
      expect(response).to redirect_to(organization_goals_health_path(company, manager_id: "everyone"))
      expect(flash[:alert]).to include("specific manager")
    end
  end
end
