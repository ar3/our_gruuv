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
      expect(response.body).to include("I'm 👇 this confident...")
      expect(response.body).to include("... will be achieved on...")
      expect(response.body).to include("... because of this reason")
      expect(response.body).to include("Switch object")
      expect(response.body).to include("for ")
      expect(response.body).to include("Switch goals owner filter")
      expect(response.body).not_to include("Owner filter")
      expect(response.body).to include("My relevant goals")
      expect(response.body).to include("All my teams")
      expect(response.body).to include("My department goals")
      expect(response.body).to include("for My relevant goals")
      expect(response.body).to include("Only Draft")
      expect(response.body).to include("Only Active")
      expect(response.body).to include("Draft + Active")
    end

    it "defaults to my_relevant_goals and includes owned plus company-visible goals" do
      create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "My owned draft")
      other_person = create(:person)
      other = create(:teammate, person: other_person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
      create(
        :goal,
        :draft,
        owner: other,
        creator: other,
        company: company,
        title: "Company wide draft",
        privacy_level: "everyone_in_company"
      )
      create(
        :goal,
        :draft,
        owner: other,
        creator: other,
        company: company,
        title: "Private other draft",
        privacy_level: "only_creator"
      )

      get organization_goals_bulk_edit_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("for My relevant goals")
      expect(response.body).to include("My owned draft")
      expect(response.body).to include("Company wide draft")
      expect(response.body).not_to include("Private other draft")
    end

    it "filters to active goals while keeping draft parent lineage" do
      parent = create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "Draft lineage parent")
      child = create(
        :goal,
        owner: teammate,
        creator: teammate,
        company: company,
        title: "Active lineage child",
        started_at: 1.week.ago
      )
      create(:goal_link, parent: parent, child: child)
      other_draft = create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "Unrelated draft")

      get organization_goals_bulk_edit_path(company, status: ["active"])
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Active lineage child")
      expect(response.body).to include("Draft lineage parent")
      expect(response.body).not_to include("Unrelated draft")
    end

    it "optgroups owner selects by type with sorted options" do
      dept_b = create(:department, company: company, name: "Zebra Dept")
      dept_a = create(:department, company: company, name: "Alpha Dept")
      team_b = create(:team, company: company, name: "Zebra Team")
      team_a = create(:team, company: company, name: "Alpha Team")
      create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "Owned draft")

      get organization_goals_bulk_edit_path(company)
      expect(response).to have_http_status(:success)

      body = response.body
      expect(body).to include("My relevant goals")
      expect(body).to include("<optgroup label=\"Teammates\">")
      expect(body).to include("<optgroup label=\"Company\">")
      expect(body).to include("<optgroup label=\"Departments\">")
      expect(body).to include("<optgroup label=\"Teams\">")
      expect(body.index("Alpha Dept")).to be < body.index("Zebra Dept")
      expect(body.index("Alpha Team")).to be < body.index("Zebra Team")
      expect(body).to include("Department_#{dept_a.id}")
      expect(body).to include("Department_#{dept_b.id}")
      expect(body).to include("Team_#{team_a.id}")
      expect(body).to include("Team_#{team_b.id}")
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
      expect(json["sheet_row"]["row_classes"]).to include("goals-sheet-row--draft")
      expect(json["sheet_row"]["popover_title"]).to eq("Draft")
    end

    it "starts the goal when confidence is set" do
      goal = create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "Start me")

      patch organization_goals_bulk_edit_goal_path(company, goal),
            params: { goal: { confidence_percentage: 80, confidence_reason: "Ready" } },
            headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:success)
      expect(goal.reload.started_at).to be_present
      json = JSON.parse(response.body)
      expect(json["started"]).to eq(true)
      expect(json["sheet_row"]["row_classes"]).to include("goals-sheet-row--active")
      expect(json["sheet_row"]["row_classes"]).not_to include("goals-sheet-row--draft")
      expect(json["sheet_row"]["popover_title"]).to be_present
      expect(json["sheet_row"]["popover_content"]).to be_present
    end

    it "returns updated track color classes when confidence changes status" do
      goal = create(
        :goal,
        owner: teammate,
        creator: teammate,
        company: company,
        title: "Track me",
        started_at: 2.weeks.ago,
        most_likely_target_date: 2.weeks.from_now,
        earliest_target_date: 1.week.from_now,
        latest_target_date: 4.weeks.from_now
      )
      create(
        :goal_check_in,
        goal: goal,
        confidence_percentage: 10,
        confidence_reason: "Low",
        check_in_week_start: Date.current.beginning_of_week(:monday)
      )

      patch organization_goals_bulk_edit_goal_path(company, goal),
            params: { goal: { confidence_percentage: 95, confidence_reason: "Looking great" } },
            headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["ok"]).to eq(true)
      expect(json["sheet_row"]["row_classes"]).to match(/goals-sheet-row--(good_green|green|yellow|red|na)/)
      expect(json["sheet_row"]["popover_title"]).to be_present
    end
  end
end
