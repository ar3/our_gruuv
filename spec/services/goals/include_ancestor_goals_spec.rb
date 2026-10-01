# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::IncludeAncestorGoals do
  let(:company) { create(:organization, :company) }
  let(:teammate) do
    create(:teammate, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  it "includes draft parents of matching active children" do
    parent = create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "Draft parent")
    child = create(
      :goal,
      owner: teammate,
      creator: teammate,
      company: company,
      title: "Active child",
      started_at: 1.week.ago
    )
    create(:goal_link, parent: parent, child: child)
    candidates = Goal.where(id: [parent.id, child.id])
    matching = candidates.active

    ids = described_class.expanded_ids(matching: matching, candidates: candidates)

    expect(ids).to contain_exactly(parent.id, child.id)
  end

  it "returns matching ids unchanged when there are no parents" do
    goal = create(:goal, owner: teammate, creator: teammate, company: company, started_at: 1.day.ago)
    matching = Goal.where(id: goal.id)

    expect(described_class.expanded_ids(matching: matching, candidates: matching)).to eq([goal.id])
  end
end
