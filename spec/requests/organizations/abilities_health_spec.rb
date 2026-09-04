# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Abilities Health", type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /organizations/:organization_id/abilities_health" do
    it "returns success and shows Expectation Alignment shell" do
      create(:ability, company: company, name: "Clarity Ability", created_by: person, updated_by: person)

      get organization_abilities_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Abilities Health")
      expect(response.body).to include("abilitiesHealthPageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Score distribution")
      expect(response.body).to include("10 best")
      expect(response.body).to include("10 worst")
      expect(response.body).to include("Clarity Ability")
      expect(response.body).to include("Scoring coming soon")
      expect(response.body).to include("Switch object")
      expect(response.body).to include("Switch page type")
      expect(response.body).to include(organization_abilities_path(company))
      expect(response.body).to include(organization_insights_abilities_path(company))
      expect(response.body).to include("Refresh missing &amp; stale")
    end

    it "lists abilities as missing scores" do
      create(:ability, company: company, name: "Needs Score", created_by: person, updated_by: person)

      get organization_abilities_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Missing &amp; stale scores")
      expect(response.body).to include("Needs Score")
      expect(response.body).to include("Missing")
    end
  end

  describe "POST /organizations/:organization_id/abilities_health_refresh" do
    it "acknowledges refresh while scoring is unavailable" do
      ability = create(:ability, company: company, name: "Refresh Me", created_by: person, updated_by: person)

      post organization_abilities_health_refresh_path(company, ability_id: ability.id)

      expect(response).to redirect_to(organization_abilities_health_path(company))
      follow_redirect!
      expect(response.body).to include("Ability Expectation Alignment scoring is coming soon")
    end
  end

  describe "POST /organizations/:organization_id/abilities_health_refresh_missing_and_stale" do
    it "acknowledges bulk refresh while scoring is unavailable" do
      create(:ability, company: company, name: "Missing", created_by: person, updated_by: person)

      post organization_abilities_health_refresh_missing_and_stale_path(company)

      expect(response).to redirect_to(organization_abilities_health_path(company))
      follow_redirect!
      expect(response.body).to include("Ability Expectation Alignment scoring is coming soon")
    end
  end
end
