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
      expect(response.body).to include("Who to show")
      expect(response.body).to include("Top-level & associated")
      expect(response.body).to include("Top-level & unassociated")
      expect(response.body).to include("Child-goals")
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
