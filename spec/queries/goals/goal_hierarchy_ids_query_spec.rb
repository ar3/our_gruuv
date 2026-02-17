# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::GoalHierarchyIdsQuery do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: company) }

  describe '#call' do
    it 'returns only the goal id when goal has no links' do
      goal = create(:goal, creator: teammate, owner: teammate, title: 'Solo')
      result = described_class.new(goal).call
      expect(result).to eq(Set[goal.id])
    end

    it 'includes self, direct parent, and direct child' do
      parent = create(:goal, creator: teammate, owner: teammate, title: 'Parent')
      middle = create(:goal, creator: teammate, owner: teammate, title: 'Middle')
      child = create(:goal, creator: teammate, owner: teammate, title: 'Child')
      create(:goal_link, parent: parent, child: middle)
      create(:goal_link, parent: middle, child: child)

      result = described_class.new(middle).call
      expect(result).to eq(Set[parent.id, middle.id, child.id])
    end

    it 'includes all ancestors up to root' do
      g1 = create(:goal, creator: teammate, owner: teammate, title: 'G1')
      g2 = create(:goal, creator: teammate, owner: teammate, title: 'G2')
      g3 = create(:goal, creator: teammate, owner: teammate, title: 'G3')
      create(:goal_link, parent: g1, child: g2)
      create(:goal_link, parent: g2, child: g3)

      result = described_class.new(g3).call
      expect(result).to eq(Set[g1.id, g2.id, g3.id])
    end

    it 'includes all descendants to leaves' do
      root = create(:goal, creator: teammate, owner: teammate, title: 'Root')
      c1 = create(:goal, creator: teammate, owner: teammate, title: 'C1')
      c2 = create(:goal, creator: teammate, owner: teammate, title: 'C2')
      gc = create(:goal, creator: teammate, owner: teammate, title: 'Grandchild')
      create(:goal_link, parent: root, child: c1)
      create(:goal_link, parent: root, child: c2)
      create(:goal_link, parent: c1, child: gc)

      result = described_class.new(root).call
      expect(result).to eq(Set[root.id, c1.id, c2.id, gc.id])
    end

    it 'includes both full ancestor and descendant trees' do
      a1 = create(:goal, creator: teammate, owner: teammate, title: 'A1')
      a2 = create(:goal, creator: teammate, owner: teammate, title: 'A2')
      mid = create(:goal, creator: teammate, owner: teammate, title: 'Mid')
      d1 = create(:goal, creator: teammate, owner: teammate, title: 'D1')
      d2 = create(:goal, creator: teammate, owner: teammate, title: 'D2')
      create(:goal_link, parent: a1, child: a2)
      create(:goal_link, parent: a2, child: mid)
      create(:goal_link, parent: mid, child: d1)
      create(:goal_link, parent: mid, child: d2)

      result = described_class.new(mid).call
      expect(result).to eq(Set[a1.id, a2.id, mid.id, d1.id, d2.id])
    end
  end
end
