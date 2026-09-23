# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Expectations Compliance", type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person, first_name: "Pat", last_name: "Viewer") }
  let(:teammate) do
    create(
      :teammate,
      person: person,
      organization: company,
      first_employed_at: 1.month.ago,
      last_terminated_at: nil,
      can_manage_employment: true
    )
  end

  before do
    create(:employment_tenure, teammate: teammate, company: company, started_at: 1.week.ago, ended_at: nil)
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /organizations/:organization_id/expectations_compliance" do
    it "returns success and shows roster signals" do
      get organization_expectations_compliance_path(company)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Insights: Expectations Compliance")
      expect(response.body).to include("Beta")
      expect(response.body).to include("expectationsCompliancePageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Who to show")
      expect(response.body).to include("Pat V.")
      expect(response.body).to include("Needs signature")
      expect(response.body).to include("Signed JD")
      expect(response.body).to include(organization_company_teammate_job_description_acknowledgements_path(company, teammate))
      expect(response.body).to include("Direct reports")
      expect(response.body).to include("Hierarchical reports")
      expect(response.body).to include("Current position")
    end

    it "appears on the Insights hub" do
      get organization_insights_path(company)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Expectations Compliance")
      expect(response.body).to include(organization_expectations_compliance_path(company))
    end
  end
end
