# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Goal Impact Scanner", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, :assigned_employee, person: person, organization: organization) }

  before do
    teammate
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/goal_impact_scanner" do
    it "renders the beta scanner with company-visible hierarchy and advisory rollup" do
      parent = create(
        :goal,
        :everyone_in_company,
        :active,
        creator: teammate,
        owner: organization,
        company: organization,
        title: "Company Rock",
        privacy_level: "everyone_in_company",
        initial_confidence: "commit",
        goal_type: "inspirational_objective",
        most_likely_target_date: Date.today + 60.days,
        started_at: 1.week.ago
      )
      child = create(
        :goal,
        :everyone_in_company,
        :active,
        creator: teammate,
        owner: teammate,
        company: organization,
        title: "Team Contributor",
        initial_confidence: "stretch",
        goal_type: "quantitative_key_result",
        most_likely_target_date: Date.today + 45.days,
        started_at: 1.week.ago
      )
      private_goal = create(
        :goal,
        :active,
        creator: teammate,
        owner: teammate,
        company: organization,
        title: "Private Goal",
        privacy_level: "only_creator_and_owner",
        most_likely_target_date: Date.today + 30.days,
        started_at: 1.week.ago
      )
      create(:goal_link, parent: parent, child: child)
      create(
        :goal_check_in,
        goal: child,
        confidence_percentage: 90,
        confidence_reporter: person,
        check_in_week_start: Date.current.beginning_of_week(:monday)
      )

      get organization_goal_impact_scanner_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Goal Impact Scanner")
      expect(response.body).to include("Beta")
      expect(response.body).to include("Company Rock")
      expect(response.body).to include("Team Contributor")
      expect(response.body).not_to include("Private Goal")
      expect(response.body).to include("Commit – Inspirational objective")
      expect(response.body).to include("Stretch – Quantitative key result")
      expect(response.body).to include("Descendant confidence")
      expect(response.body).to include("1 ≥80%")
      expect(response.body).to include("Avg 90.0%")
      expect(response.body).to include("(advisory)")
      expect(response.body).not_to include("Bands:")
      expect(private_goal.title).to eq("Private Goal")
    end

    it "shows empty state when there are no company-visible goals" do
      get organization_goal_impact_scanner_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("No company-visible goals yet")
    end
  end
end
