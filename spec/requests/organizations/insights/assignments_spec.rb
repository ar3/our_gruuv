# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Insights assignments", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/insights/assignments" do
    it "returns success and shows Assignments object lens header" do
      get organization_insights_assignments_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Switch object")
      expect(response.body).to include("Switch page type")
      expect(response.body).to include(organization_assignments_path(organization))
      expect(response.body).to include(organization_assignments_health_path(organization))
      expect(response.body).to include("Distribution of outcomes per assignment")
    end
  end
end
