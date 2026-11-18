# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Goals Progressive Outcome", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    person.company_teammates.find_or_create_by!(organization: organization) do |t|
      t.first_employed_at = nil
      t.last_terminated_at = nil
    end
  end

  before do
    PaperTrail.enabled = false
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    sign_in_as_teammate_for_request(person, organization)
  end

  after { PaperTrail.enabled = true }

  it "creates a progressive outcome from prose and shows the panel" do
    expect do
      post organization_goals_path(organization), params: {
        goal: {
          title: "Move retention from 50% to [60|70|80]%",
          owner_id: "CompanyTeammate_#{teammate.id}",
          goal_type: "progressive_outcome",
          progressive_create_mode: "progressive",
          privacy_level: "only_creator_owner_and_managers",
          edit_check_in_permission: "anyone_who_can_view",
          timeframe: "near_term"
        }
      }
    end.to change(Goal, :count).by(1)

    goal = Goal.order(:id).last
    expect(response).to redirect_to(organization_goal_path(organization, goal, anchor: "check-in"))
    expect(goal.goal_type).to eq("progressive_outcome")
    expect(goal.outcome_commit).to eq(BigDecimal("60"))
    expect(goal.progressive_current_aim).to eq("commit")

    get organization_goal_path(organization, goal)
    expect(response).to have_http_status(:success)
    expect(response.body).to include("OG3 Progressive Outcome")
    # No leftover bare type pill (duplicate under title was "Progressive Outcome" alone)
    expect(response.body).not_to match(/>\s*Progressive Outcome\s*</)
    expect(response.body).to include("Current aim")
    expect(response.body).to include("The Baseline")
    expect(response.body).to include("The COMMIT")
    expect(response.body).to include("The STRETCH")
    expect(response.body).to include("The TRANSFORM")
    expect(response.body).to include("og3-outcome-value")
    expect(response.body).to include("Show details")
    expect(response.body).to include("Record hit in confidence checks")
    expect(response.body).not_to include("Advance ladder")
    expect(response.body).to include("optionally advance the OG3 ladder")
    expect(response.body).to include("#check-in")
    expect(response.body).to include("60%")
    expect(response.body).to include("og3-outcome-value--current")
    expect(response.body).to include("goalShowPageHelp")
    expect(response.body).to include("OG3 Goals")
    expect(response.body).to include(og3_goals_path)
  end

  it "advances the OG3 ladder from a 100% check-in with advance selected" do
    goal = create(
      :goal,
      creator: teammate,
      owner: teammate,
      company: organization,
      goal_type: "progressive_outcome",
      title: "Move retention from 50% to [60|70|80]%",
      outcome_baseline: 50,
      outcome_commit: 60,
      outcome_stretch: 70,
      outcome_transform: 80,
      outcome_unit: "%",
      progressive_current_aim: "commit",
      started_at: 1.week.ago,
      most_likely_target_date: Date.current + 1.month,
      privacy_level: "everyone_in_company",
      edit_check_in_permission: "anyone_who_can_view"
    )

    expect do
      post check_in_organization_goal_path(organization, goal), params: {
        confidence_percentage: "100_advance",
        confidence_reason: "Hit commit. Climbing to stretch."
      }
    end.to change(Goal, :count).by(1)

    goal.reload
    expect(goal.completed_at).to be_present
    expect(goal.goal_check_ins.recent.first.confidence_percentage).to eq(100)

    next_goal = Goal.order(:id).last
    expect(next_goal.progressive_current_aim).to eq("stretch")
    expect(response).to redirect_to(organization_goal_path(organization, next_goal, anchor: "check-in"))
    expect(flash[:notice]).to include("Advanced OG3 ladder to Stretch")
  end

  it "shows OG3 field guidance on the edit page" do
    goal = create(
      :goal,
      creator: teammate,
      owner: teammate,
      company: organization,
      goal_type: "progressive_outcome",
      title: "Move retention from 50% to [60|70|80]%",
      outcome_baseline: 50,
      outcome_commit: 60,
      outcome_stretch: 70,
      outcome_transform: 80,
      outcome_unit: "%",
      progressive_current_aim: "commit",
      started_at: 1.week.ago,
      privacy_level: "everyone_in_company",
      edit_check_in_permission: "anyone_who_can_view"
    )

    get edit_organization_goal_path(organization, goal)
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Where you started before this push")
    expect(response.body).to include("≈80%+ confident")
    expect(response.body).to include("coin-flip")
    expect(response.body).to include("near-impossible bar")
    expect(response.body).to include("weekly confidence checks track")
    expect(response.body).to include("What the numbers are in")
  end

  it "expands into parent + three children" do
    expect do
      post organization_goals_path(organization), params: {
        goal: {
          title: "Move retention from 50% to Commit:60%, Stretch:70%, Transform:80%",
          owner_id: "CompanyTeammate_#{teammate.id}",
          goal_type: "progressive_outcome",
          progressive_create_mode: "expand_now",
          privacy_level: "only_creator_owner_and_managers",
          edit_check_in_permission: "anyone_who_can_view",
          timeframe: "near_term"
        }
      }
    end.to change(Goal, :count).by(4)

    parent = Goal.order(:id).find_by(goal_type: "inspirational_objective")
    expect(response).to redirect_to(organization_goal_path(organization, parent, anchor: "check-in"))
  end
end
