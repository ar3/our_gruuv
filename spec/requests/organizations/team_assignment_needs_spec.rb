# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Team assignment needs", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:team) { create(:team, company: organization, name: "Platform") }
  let!(:assignment_required) { create(:assignment, company: organization, title: "Incident Commander") }
  let!(:assignment_nice) { create(:assignment, company: organization, title: "Docs Maintainer") }

  let(:teammate) do
    create(:teammate, person: person, organization: organization,
           first_employed_at: 1.year.ago, last_terminated_at: nil,
           can_manage_departments_and_teams: true)
  end

  before do
    create(:team_member, team: team, company_teammate: teammate)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET manage_assignment_needs" do
    it "renders the assignment needs page" do
      get manage_assignment_needs_organization_team_path(organization, team)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("What assignments does this team need?")
      expect(response.body).to include("Incident Commander")
      expect(response.body).to include("Docs Maintainer")
    end
  end

  describe "PATCH update_assignment_needs" do
    it "creates and updates team assignment needs" do
      patch update_assignment_needs_organization_team_path(organization, team), params: {
        need_types: {
          assignment_required.id.to_s => "required",
          assignment_nice.id.to_s => "nice_to_have"
        }
      }

      expect(response).to redirect_to(organization_team_path(organization, team))
      expect(team.team_assignment_needs.pluck(:assignment_id, :need_type)).to contain_exactly(
        [assignment_required.id, "required"],
        [assignment_nice.id, "nice_to_have"]
      )
    end

    it "removes needs marked as not needed" do
      create(:team_assignment_need, team: team, assignment: assignment_required)

      patch update_assignment_needs_organization_team_path(organization, team), params: {
        need_types: {
          assignment_required.id.to_s => "",
          assignment_nice.id.to_s => "nice_to_have"
        }
      }

      expect(team.team_assignment_needs.pluck(:assignment_id)).to eq([assignment_nice.id])
    end
  end

  describe "team show roster" do
    let!(:need) { create(:team_assignment_need, team: team, assignment: assignment_required) }
    let(:coverer) { create(:company_teammate, organization: organization, person: create(:person, first_name: "Alex", last_name: "Rivera")) }

    before do
      create(:team_assignment_coverer, team_assignment_need: need, company_teammate: coverer)
    end

    it "shows assignment needs, coverers, and discrepancies" do
      get organization_team_path(organization, team)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Team Assignments")
      expect(response.body).to include("Incident Commander")
      expect(response.body).to include("Alex")
      expect(response.body).to include("No active assignment")
      expect(response.body).to include("Not on team")
    end
  end

  describe "manage coverers flow" do
    let!(:need) { create(:team_assignment_need, team: team, assignment: assignment_required) }
    let(:coverer) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago, last_terminated_at: nil) }
    let!(:non_member) { create(:company_teammate, organization: organization, first_employed_at: 1.year.ago, last_terminated_at: nil) }

    it "updates coverers for a team assignment need" do
      get manage_coverers_organization_team_assignment_need_path(organization, team, need)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Who is taking this on for the team?")
      expect(response.body).to include("Below are those on the")
      expect(response.body).to include("but do not currently have")
      expect(response.body).to include("Below are folks not on")
      expect(response.body).to include("It should be rare that they are taking on")

      patch update_coverers_organization_team_assignment_need_path(organization, team, need), params: {
        coverer_ids: [coverer.id]
      }

      expect(response).to redirect_to(organization_team_path(organization, team))
      expect(need.reload.company_teammate_ids).to eq([coverer.id])
    end

    it "lists team members with the assignment in the first group" do
      team_member_with_assignment = create(:company_teammate, organization: organization, first_employed_at: 1.year.ago, last_terminated_at: nil)
      create(:team_member, team: team, company_teammate: team_member_with_assignment)
      create(:assignment_tenure, teammate: team_member_with_assignment, assignment: assignment_required, started_at: 1.month.ago)

      get manage_coverers_organization_team_assignment_need_path(organization, team, need)

      expect(response.body).to include("Currently have this assignment")
      expect(response.body).to include(team_member_with_assignment.person.preferred_first_then_last_display_name)
    end
  end
end
