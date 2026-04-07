# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GoalAssociation, type: :model do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:other_org) { create(:organization) }
  let(:other_assignment) { create(:assignment, company: other_org) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:goal) do
    create(
      :goal,
      company_id: organization.id,
      creator: teammate,
      owner: teammate,
      goal_type: 'inspirational_objective',
      most_likely_target_date: nil,
      earliest_target_date: nil,
      latest_target_date: nil
    )
  end

  it 'is valid with matching company' do
    expect(build(:goal_association, associable: assignment, goal: goal)).to be_valid
  end

  it 'rejects mismatched company' do
    ga = build(:goal_association, associable: other_assignment, goal: goal)
    expect(ga).not_to be_valid
    expect(ga.errors[:goal]).to be_present
  end

  it 'enforces uniqueness per goal and associable' do
    create(:goal_association, associable: assignment, goal: goal)
    dup = build(:goal_association, associable: assignment, goal: goal)
    expect(dup).not_to be_valid
    expect(dup.errors[:goal_id]).to be_present
  end

  it 'allows same goal on different associables' do
    a2 = create(:assignment, company: organization)
    create(:goal_association, associable: assignment, goal: goal)
    expect(build(:goal_association, associable: a2, goal: goal)).to be_valid
  end
end
