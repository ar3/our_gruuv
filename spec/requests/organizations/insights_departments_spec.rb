# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Insights Departments", type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /organizations/:organization_id/insights/departments" do
    it "returns success and shows department averages and chart" do
      department = create(:department, company: company, name: "Engineering")
      create(:assignment, company: company, department: department)
      create(:ability, company: company, department: department)

      get organization_insights_departments_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Insights: Departments")
      expect(response.body).to include("Active departments")
      expect(response.body).to include("Avg assignments / dept")
      expect(response.body).to include("Avg abilities / dept")
      expect(response.body).to include("Avg seats / dept")
      expect(response.body).to include("departments-coverage-chart")
      expect(response.body).to include("Switch object")
      expect(response.body).to include(organization_departments_path(company))
      expect(response.body).to include(organization_departments_health_path(company))
    end
  end
end
