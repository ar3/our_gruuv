# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::GoalsSummaryStats do
  let(:company) { create(:organization, :company) }
  let(:person_a) { create(:person, first_name: "Ada", last_name: "Creator") }
  let(:person_b) { create(:person, first_name: "Bob", last_name: "Owner") }
  let!(:teammate_a) { create(:teammate, person: person_a, organization: company) }
  let!(:teammate_b) { create(:teammate, person: person_b, organization: company) }
  let(:range) { 30.days.ago..Time.current }
  let(:goals_scope) { Goal.where(company: company).where(deleted_at: nil) }

  def personal_goal!(owner:, creator: owner, attrs: {})
    create(
      :goal,
      :active,
      {
        owner: owner,
        creator: creator,
        company_id: company.id,
        goal_type: "qualitative_key_result",
        privacy_level: "everyone_in_company"
      }.merge(attrs)
    )
  end

  subject(:result) { described_class.new(goals_scope: goals_scope, range: range).call }

  it "counts created goals and distinct creators in the range" do
    personal_goal!(owner: teammate_a, attrs: { created_at: 10.days.ago })
    personal_goal!(owner: teammate_b, creator: teammate_a, attrs: { created_at: 5.days.ago })
    personal_goal!(owner: teammate_b, attrs: { created_at: 60.days.ago })

    expect(result.created_goals_count).to eq(2)
    expect(result.created_teammates_count).to eq(1)
  end

  it "counts goals with a confidence check and distinct reporters in the range" do
    checked = personal_goal!(owner: teammate_a, attrs: { created_at: 60.days.ago })
    unchecked = personal_goal!(owner: teammate_b, attrs: { created_at: 60.days.ago })
    create(
      :goal_check_in,
      goal: checked,
      confidence_reporter: person_a,
      created_at: 3.days.ago,
      check_in_week_start: 3.days.ago.beginning_of_week(:monday)
    )
    create(
      :goal_check_in,
      goal: unchecked,
      confidence_reporter: person_b,
      created_at: 60.days.ago,
      check_in_week_start: 60.days.ago.beginning_of_week(:monday)
    )

    expect(result.confidence_checked_goals_count).to eq(1)
    expect(result.confidence_checked_teammates_count).to eq(1)
  end

  it "counts stale goals created before the range with no confidence check in the range" do
    stale = personal_goal!(owner: teammate_a, attrs: { created_at: 60.days.ago })
    personal_goal!(owner: teammate_b, attrs: { created_at: 10.days.ago })
    checked_old = personal_goal!(owner: teammate_b, attrs: { created_at: 45.days.ago })
    create(
      :goal_check_in,
      goal: checked_old,
      confidence_reporter: person_b,
      created_at: 2.days.ago,
      check_in_week_start: 2.days.ago.beginning_of_week(:monday)
    )

    expect(result.stale_goals_count).to eq(1)
    expect(result.stale_teammates_count).to eq(1)
    expect(stale.owner_id).to eq(teammate_a.id)
  end

  it "counts completed goals and distinct owners in the range" do
    personal_goal!(
      owner: teammate_a,
      attrs: { created_at: 60.days.ago, completed_at: 4.days.ago }
    )
    personal_goal!(
      owner: teammate_b,
      attrs: { created_at: 60.days.ago, completed_at: 2.days.ago }
    )
    personal_goal!(
      owner: teammate_a,
      attrs: { created_at: 60.days.ago, completed_at: 60.days.ago }
    )

    expect(result.completed_goals_count).to eq(2)
    expect(result.completed_teammates_count).to eq(2)
  end
end
