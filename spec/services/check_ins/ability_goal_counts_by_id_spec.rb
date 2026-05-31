# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::AbilityGoalCountsById do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:ability) { create(:ability, company: organization) }
  let(:other_ability) { create(:ability, company: organization) }

  def create_associated_goal(ability:, started_at: nil, completed_at: nil)
    goal = create(
      :goal,
      owner: teammate,
      creator: teammate,
      started_at: started_at,
      completed_at: completed_at
    )
    create(:goal_association, goal: goal, associable: ability)
    goal
  end

  it "returns empty hash when ability ids are blank" do
    expect(described_class.call(teammate: teammate, ability_ids: [])).to eq({})
  end

  it "counts draft, active, and completed goals per ability" do
    create_associated_goal(ability: ability, started_at: nil, completed_at: nil)
    create_associated_goal(ability: ability, started_at: 1.week.ago, completed_at: nil)
    create_associated_goal(ability: ability, started_at: 2.weeks.ago, completed_at: 1.day.ago)
    create_associated_goal(ability: other_ability, started_at: 3.days.ago, completed_at: nil)

    expect(described_class.call(teammate: teammate, ability_ids: [ability.id, other_ability.id])).to eq(
      ability.id => { draft: 1, active: 1, completed: 1 },
      other_ability.id => { draft: 0, active: 1, completed: 0 }
    )
  end

  it "ignores deleted goals and goals owned by other teammates" do
    create_associated_goal(ability: ability, started_at: 1.week.ago, completed_at: nil)
    deleted_goal = create_associated_goal(ability: ability, started_at: 1.week.ago, completed_at: nil)
    deleted_goal.update!(deleted_at: Time.current)

    other_teammate = create(:teammate, organization: organization)
    other_goal = create(:goal, owner: other_teammate, creator: other_teammate, started_at: 1.week.ago)
    create(:goal_association, goal: other_goal, associable: ability)

    expect(described_class.call(teammate: teammate, ability_ids: [ability.id])).to eq(
      ability.id => { draft: 0, active: 1, completed: 0 }
    )
  end
end
