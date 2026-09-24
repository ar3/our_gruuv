# frozen_string_literal: true

require "rails_helper"

RSpec.describe MyGrowth::CurrentPositionMilestoneGaps do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: company) }
  let!(:employment) do
    create(:employment_tenure, teammate: teammate, company: company, started_at: 1.year.ago, ended_at: nil)
  end
  let(:position) { employment.position }
  let(:ability) { create(:ability, company: company, name: "GapAbility") }

  before do
    create(:position_ability, position: position, ability: ability, milestone_level: 2)
  end

  it "lists required milestones and flags unmet gaps without active goals" do
    result = described_class.call(teammate: teammate)
    expect(result.position).to eq(position)
    expect(result.rows.size).to eq(1)
    row = result.rows.first
    expect(row.ability).to eq(ability)
    expect(row.required_level).to eq(2)
    expect(row.met).to be(false)
    expect(row.has_active_goal).to be(false)
    expect(row.active_goals).to eq([])
  end

  it "includes active goal details when a started goal covers the gap" do
    goal = create(
      :goal,
      owner: teammate,
      creator: teammate,
      company_id: company.id,
      title: "Close the gap",
      started_at: 1.week.ago
    )
    create(:goal_association, goal: goal, associable: ability)

    row = described_class.call(teammate: teammate).rows.first
    expect(row.has_active_goal).to be(true)
    expect(row.active_goal_count).to eq(1)
    expect(row.active_goals.map { |g| g[:title] }).to eq(["Close the gap"])
  end

  it "counts drafts separately and omits them from active_goals" do
    draft = create(
      :goal,
      owner: teammate,
      creator: teammate,
      company_id: company.id,
      title: "Draft only",
      started_at: nil
    )
    create(:goal_association, goal: draft, associable: ability)

    row = described_class.call(teammate: teammate).rows.first
    expect(row.has_active_goal).to be(false)
    expect(row.draft_goal_count).to eq(1)
    expect(row.active_goals).to eq([])
  end

  it "marks rows met when the milestone is earned" do
    create(:teammate_milestone, company_teammate: teammate, ability: ability, milestone_level: 2)
    result = described_class.call(teammate: teammate)
    expect(result.rows.first.met).to be(true)
  end
end
