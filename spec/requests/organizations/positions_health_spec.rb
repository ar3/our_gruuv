# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::PositionsHealth", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }
  let(:major_level) { create(:position_major_level) }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /positions_health" do
    it "renders Position Health with object lens, legend, refresh, and page help" do
      title = create(:title, company: organization, position_major_level: major_level, external_title: "Engineer", end_cap: true)
      Titles::ExpectationAlignmentScore.recalculate!(title: title, refresh_positions: false)

      get organization_positions_health_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Position Health")
      expect(response.body).to include("positionsHealthPageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Switch object")
      expect(response.body).to include(organization_positions_path(organization))
      expect(response.body).to include(organization_insights_seats_titles_positions_path(organization))
      expect(response.body).to include("Refresh all")
      expect(response.body).to include("Titles")
      expect(response.body).to include("Unscored")
      expect(response.body).to include("Company-wide")
      expect(response.body).to include("Engineer")
      expect(response.body).to include("#title-expectation-alignment-score")
    end
  end

  describe "POST /positions_health_refresh_all" do
    it "enqueues a title EAS refresh for each unarchived title" do
      a = create(:title, company: organization, position_major_level: major_level, external_title: "A")
      b = create(:title, company: organization, position_major_level: major_level, external_title: "B")

      expect {
        post organization_positions_health_refresh_all_path(organization)
      }.to have_enqueued_job(TitleExpectationAlignmentScoreRefreshJob).with(a.id)
        .and have_enqueued_job(TitleExpectationAlignmentScoreRefreshJob).with(b.id)

      expect(response).to redirect_to(organization_positions_health_path(organization))
    end
  end
end
