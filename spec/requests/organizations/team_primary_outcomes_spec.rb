# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Team primary outcomes", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:team) { create(:team, company: organization, name: "Platform") }
  let(:assignment) { create(:assignment, company: organization, title: "Incident Commander") }
  let!(:need) { create(:team_assignment_need, team: team, assignment: assignment) }
  let!(:outcome) do
    create(:assignment_outcome, assignment: assignment, description: "Incidents resolved within SLA")
  end

  let(:teammate) do
    create(:teammate, person: person, organization: organization,
           first_employed_at: 1.year.ago, last_terminated_at: nil,
           can_manage_departments_and_teams: true)
  end

  before do
    create(:team_member, team: team, company_teammate: teammate)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET team show" do
    it "prompts team admins to pick primary outcomes when none are selected" do
      get organization_team_path(organization, team)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Primary Outcomes")
      expect(response.body).to include("Team admin: pick primary outcomes")
      expect(response.body).to include(manage_primary_outcomes_organization_team_path(organization, team))
    end

    it "lists selected primary outcomes above team assignments" do
      create(:team_primary_outcome, team: team, assignment_outcome: outcome)

      get organization_team_path(organization, team)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Incidents resolved within SLA")
      expect(response.body).to include("Incident Commander")
      expect(response.body.index("Primary Outcomes")).to be < response.body.index("Team Assignments")
    end
  end

  describe "GET manage_primary_outcomes" do
    it "renders candidate outcomes from needed assignments" do
      get manage_primary_outcomes_organization_team_path(organization, team)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("What outcomes is this team for?")
      expect(response.body).to include("Incidents resolved within SLA")
      expect(response.body).to include("Incident Commander")
    end
  end

  describe "PATCH update_primary_outcomes" do
    it "saves selected primary outcomes" do
      patch update_primary_outcomes_organization_team_path(organization, team), params: {
        assignment_outcome_ids: [outcome.id]
      }

      expect(response).to redirect_to(organization_team_path(organization, team))
      expect(team.team_primary_outcomes.pluck(:assignment_outcome_id)).to eq([outcome.id])
    end

    it "ignores outcomes from assignments the team does not need" do
      other_assignment = create(:assignment, company: organization)
      other_outcome = create(:assignment_outcome, assignment: other_assignment, description: "Elsewhere")

      patch update_primary_outcomes_organization_team_path(organization, team), params: {
        assignment_outcome_ids: [outcome.id, other_outcome.id]
      }

      expect(team.team_primary_outcomes.pluck(:assignment_outcome_id)).to eq([outcome.id])
    end
  end
end
