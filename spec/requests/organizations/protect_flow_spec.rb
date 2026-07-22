# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::ProtectFlow", type: :request do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person) }
  let(:manager) do
    create(
      :company_teammate,
      person: manager_person,
      organization: company,
      first_employed_at: 1.month.ago,
      last_terminated_at: nil
    )
  end
  let(:report_person) { create(:person, first_name: "Alex", last_name: "River") }
  let(:report) do
    create(
      :company_teammate,
      person: report_person,
      organization: company,
      first_employed_at: 1.month.ago,
      last_terminated_at: nil
    )
  end

  before do
    manager
    report
    create(:employment_tenure, company_teammate: report, company: company, manager_teammate: manager)
    EngagementHealth::CATEGORIES.each do |category|
      status = category == EngagementHealth::CATEGORY_REQUIRED_CLARITY ? EngagementHealth::NEEDS_ATTENTION : EngagementHealth::HEALTHY
      EngagementHealthStatus.create!(
        teammate: report,
        organization: company,
        level: "category",
        category: category,
        status: status,
        inputs: {},
        computed_at: Time.current
      )
    end
    EngagementHealthStatus.create!(
      teammate: report,
      organization: company,
      level: "item",
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      entity_type: "Assignment",
      entity_id: 101,
      status: EngagementHealth::NEEDS_ATTENTION,
      inputs: { "name" => "Clarity Item A" },
      computed_at: Time.current
    )
    sign_in_as_teammate_for_request(manager_person, company)
  end

  describe "GET /organizations/:organization_id/protect_flow" do
    it "renders the page for a manager with direct reports" do
      get organization_protect_flow_path(company)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Protect Flow")
      expect(response.body).to include("Protect flow — stale clarity kills it")
      expect(response.body).to include("Alex")
      expect(response.body).to include("unhealthy vectors")
      expect(response.body).to include("Who to show")
      expect(response.body).to include("Protect Flow")
      expect(response.body).to include("Check-ins")
      expect(response.body).not_to include(">Everyone<")
      expect(response.body).not_to include("Mark done")
      expect(response.body).to include("Clarity Item A")
      expect(response.body).not_to include("Top items")
    end

    it "rejects everyone scope and falls back to my direct employees" do
      get organization_protect_flow_path(company, manager_id: "everyone")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Alex")
      expect(response.body).to match(/value=["']my_direct_employees["'][^>]*selected|selected[^>]*value=["']my_direct_employees["']/)
      expect(response.body).not_to include('value="everyone"')
    end

    it "forbids teammates without direct reports" do
      employee_person = create(:person)
      create(:company_teammate, person: employee_person, organization: company, first_employed_at: 1.month.ago)
      sign_in_as_teammate_for_request(employee_person, company)

      get organization_protect_flow_path(company)

      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end

    it "shows progress after health improves without manual completion" do
      get organization_protect_flow_path(company)
      expect(response.body).to include("1→1")

      EngagementHealthStatus.find_by!(
        teammate: report,
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        level: "category"
      ).update!(status: EngagementHealth::HEALTHY)
      EngagementHealthStatus.find_by!(
        teammate: report,
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        level: "item"
      ).update!(status: EngagementHealth::HEALTHY)

      get organization_protect_flow_path(company)
      expect(response.body).to include("1→0")
      expect(response.body).to include("Clear")
      expect(response.body).to include("Clarity Check-ins")
      expect(response.body).not_to include("Hero action")
      expect(response.body).to include("Why is this important?")
    end
  end
end
