require "rails_helper"

RSpec.describe "Organizations::Sitemap", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/sitemap" do
    it "returns success and lists accessible pages" do
      get organization_sitemap_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Sitemap")
      expect(response.body).to include("Milestones &amp; Abilities")
      expect(response.body).to include("Also known as")
    end
  end
end
