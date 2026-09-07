# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Goals Bulk Edit", type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /organizations/:organization_id/goals/bulk_edit" do
    it "returns success and shows sheet chrome" do
      create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "Visible draft")

      get organization_goals_bulk_edit_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bulk Edit Goals")
      expect(response.body).to include("goalsBulkEditPageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Beta")
      expect(response.body).to include("bi-flask")
      expect(response.body).to include("Draft until confidence is set")
      expect(response.body).to include("goals-sheet-row__status")
      expect(response.body).to include("data-bs-toggle=\"popover\"")
      expect(response.body).to include("Grey means this goal is still a draft")
      expect(response.body).to include("Add top-level goal")
      expect(response.body).to include("Visible draft")
      expect(response.body).to include("check-in-autosave")
      expect(response.body).to include("Switch object")
      expect(response.body).to include("for ")
      expect(response.body).to include("Switch goals owner filter")
      expect(response.body).not_to include("Owner filter")
    end
  end

  describe "POST /organizations/:organization_id/goals/bulk_edit" do
    it "creates a top-level draft goal and redirects back to the sheet" do
      expect do
        post organization_goals_bulk_edit_create_path(company), params: {
          owner_id: "CompanyTeammate_#{teammate.id}",
          goal: {
            title: "New sheet goal",
            goal_type: "inspirational_objective",
            owner_id: "CompanyTeammate_#{teammate.id}"
          }
        }
      end.to change(Goal, :count).by(1)

      expect(response).to redirect_to(organization_goals_bulk_edit_path(company, owner_id: "CompanyTeammate_#{teammate.id}"))
      goal = Goal.order(:id).last
      expect(goal.title).to eq("New sheet goal")
      expect(goal.started_at).to be_nil
    end

    it "creates a child under a parent" do
      parent = create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "Parent")

      post organization_goals_bulk_edit_create_path(company), params: {
        owner_id: "CompanyTeammate_#{teammate.id}",
        parent_id: parent.id,
        goal: {
          title: "Child sheet goal",
          goal_type: "stepping_stone_activity",
          owner_id: "CompanyTeammate_#{teammate.id}"
        }
      }

      child = Goal.find_by(title: "Child sheet goal")
      expect(child).to be_present
      expect(GoalLink.exists?(parent_id: parent.id, child_id: child.id)).to eq(true)
    end
  end

  describe "PATCH /organizations/:organization_id/goals/bulk_edit/:id" do
    it "autosaves title as JSON" do
      goal = create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "Before")

      patch organization_goals_bulk_edit_goal_path(company, goal),
            params: { goal: { title: "After" } },
            headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["ok"]).to eq(true)
      expect(goal.reload.title).to eq("After")
      expect(goal.started_at).to be_nil
    end

    it "starts the goal when confidence is set" do
      goal = create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "Start me")

      patch organization_goals_bulk_edit_goal_path(company, goal),
            params: { goal: { confidence_percentage: 80, confidence_reason: "Ready" } },
            headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:success)
      expect(goal.reload.started_at).to be_present
      expect(JSON.parse(response.body)["started"]).to eq(true)
    end
  end
end
