# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::PositionLevelSets", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:major) { create(:position_major_level, set_name: "Base 10x3", major_level: 2, description: "Mid Career") }

  before do
    create(:teammate, person: person, organization: organization)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/position_level_sets/:name" do
    it "explains the set and lists majors" do
      get organization_position_level_set_path(organization, "Base 10x3")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Base 10x3")
      expect(response.body).to include("positionLevelSetPageHelp")
      expect(response.body).to include("What is a position level set?")
      expect(response.body).to include("OG representative")
      expect(response.body).to include("L:2.*")
      expect(response.body).to include("Mid Career")
      expect(response.body).to include(organization_position_major_level_path(organization, major))
    end

    it "returns not found for an unknown set" do
      get organization_position_level_set_path(organization, "Unknown Set")

      expect(response).to have_http_status(:not_found)
    end
  end
end
