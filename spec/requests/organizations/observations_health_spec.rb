# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Observations Health", type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil, can_manage_employment: true)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /organizations/:organization_id/observations_health" do
    it "returns success and shows key sections" do
      get organization_observations_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Observations Health")
      expect(response.body).to include("observationsHealthPageInfo")
      expect(response.body).to include("Ultimate goal")
      expect(response.body).to include("Who to show")
      expect(response.body).to include("Given")
      expect(response.body).to include("Received")
      expect(response.body).to include("Kudos mix")
      expect(response.body).to include("Rating intensity")
      expect(response.body).to include("Refresh all in this view")
      expect(response.body).to include("Company Observations Insights")
      expect(response.body).to include('data-bs-toggle="popover"')
      expect(response.body).to include("Spotlight Healthy / Warning / Needs Attention uses only Given and Received")
      expect(response.body).to include("Download OGOs (CSV)")
      expect(response.body).to include("Download employees observations summary (CSV)")
    end

    it "shows health dashboard switcher with links to check-ins and goals health" do
      get organization_observations_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(organization_check_ins_health_path(company, manager_id: "everyone"))
      expect(response.body).to include(organization_goals_health_path(company, manager_id: "everyone"))
    end

    it "with manager_id=just_me returns success" do
      get organization_observations_health_path(company), params: { manager_id: "just_me" }
      expect(response).to have_http_status(:success)
    end

    it "shows Gruuv Health Given/Received and mix columns from cache" do
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: company,
        level: "category",
        category: EngagementHealth::CATEGORY_OGO_GIVEN,
        status: EngagementHealth::HEALTHY,
        inputs: { "last_event_at" => 1.day.ago.iso8601, "never" => false },
        computed_at: Time.current
      )
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: company,
        level: "category",
        category: EngagementHealth::CATEGORY_OGO_RECEIVED,
        status: EngagementHealth::WARNING,
        inputs: { "last_event_at" => 45.days.ago.iso8601, "never" => false },
        computed_at: Time.current
      )
      create(
        :observation_health_cache,
        teammate: teammate,
        organization: company,
        payload: {
          "given" => { "status" => "green", "observations_count" => 2 },
          "received" => { "status" => "yellow", "observations_count" => 1 },
          "kudos_mix" => { "band" => "healthy", "kudos_count" => 2, "constructive_count" => 1, "display_ratio" => "2:1" },
          "rating_intensity" => { "band" => "healthy", "less_extreme_count" => 1, "most_extreme_count" => 1, "display_ratio" => "1:1" },
          "overall_status" => "yellow"
        }
      )

      get organization_observations_health_path(company), params: { manager_id: "just_me" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("2:1")
      expect(response.body).to include("Warning")
      expect(response.body).to include("bi-arrow-clockwise")
    end
  end

  describe "GET /organizations/:organization_id/observations_health_export" do
    it "returns CSV attachment" do
      get organization_observations_health_export_path(company)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end
  end

  describe "GET /organizations/:organization_id/observations_health_employee_summary_export" do
    it "returns CSV attachment" do
      get organization_observations_health_employee_summary_export_path(company)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end
  end

  describe "POST /organizations/:organization_id/observations_health_refresh" do
    it "enqueues Gruuv Health and observation mix refresh for the teammate" do
      expect {
        post organization_observations_health_refresh_path(company), params: { teammate_id: teammate.id }
      }.to have_enqueued_job(ObservationHealthCacheRefreshJob).with(teammate.id)
        .and have_enqueued_job(EngagementHealthRefreshJob).with(teammate.id)
      expect(response).to redirect_to(organization_observations_health_path(company))
    end
  end

  describe "POST /organizations/:organization_id/observations_health_refresh_all" do
    it "enqueues refresh for filtered teammates" do
      expect {
        post organization_observations_health_refresh_all_path(company), params: { manager_id: "just_me" }
      }.to have_enqueued_job(ObservationHealthCacheRefreshJob).with(teammate.id)
        .and have_enqueued_job(EngagementHealthRefreshJob).with(teammate.id)
    end
  end
end
