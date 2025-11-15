require 'rails_helper'

RSpec.describe Goals::HierarchyQuery do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: company) }
  let(:person) { teammate.person }

  describe '#call' do
    context 'with the structure: Goal 14 -> [15, 16, 17], Goal 16 -> [18]' do
      let!(:goal_14) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 14') }
      let!(:goal_15) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 15') }
      let!(:goal_16) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 16') }
      let!(:goal_17) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 17') }
      let!(:goal_18) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 18') }

      let!(:link_14_to_15) do
        create(:goal_link,
               parent: goal_14,
               child: goal_15)
      end
      let!(:link_14_to_16) do
        create(:goal_link,
               parent: goal_14,
               child: goal_16)
      end
      let!(:link_14_to_17) do
        create(:goal_link,
               parent: goal_14,
               child: goal_17)
      end
      let!(:link_16_to_18) do
        create(:goal_link,
               parent: goal_16,
               child: goal_18)
      end

      let(:goals) { [goal_14, goal_15, goal_16, goal_17, goal_18] }
      let(:query) { described_class.new(goals: goals) }

      it 'identifies goal_14 as the only root goal' do
        result = query.call
        expect(result[:root_goals]).to contain_exactly(goal_14)
      end

      it 'builds correct parent-child map' do
        result = query.call
        parent_child_map = result[:parent_child_map]

        expect(parent_child_map[goal_14.id]).to contain_exactly(goal_15, goal_16, goal_17)
        expect(parent_child_map[goal_16.id]).to contain_exactly(goal_18)
        expect(parent_child_map[goal_15.id]).to be_empty
        expect(parent_child_map[goal_17.id]).to be_empty
        expect(parent_child_map[goal_18.id]).to be_empty
      end

      it 'includes all relevant links' do
        result = query.call
        link_ids = result[:links].map(&:id)
        
        expect(link_ids).to include(link_14_to_15.id, link_14_to_16.id, link_14_to_17.id, link_16_to_18.id)
      end

      describe '#root_goals' do
        it 'returns only goal_14' do
          expect(query.root_goals).to contain_exactly(goal_14)
        end
      end

      describe '#parent_child_map' do
        it 'returns correct mapping' do
          map = query.parent_child_map
          expect(map[goal_14.id]).to contain_exactly(goal_15, goal_16, goal_17)
          expect(map[goal_16.id]).to contain_exactly(goal_18)
        end
      end
    end

    context 'with multiple root goals' do
      let!(:root_goal_1) { create(:goal, creator: teammate, owner: teammate, title: 'Root 1') }
      let!(:root_goal_2) { create(:goal, creator: teammate, owner: teammate, title: 'Root 2') }
      let!(:child_1) { create(:goal, creator: teammate, owner: teammate, title: 'Child 1') }
      
      let!(:link_root1_to_child1) do
        create(:goal_link,
               parent: root_goal_1,
               child: child_1)
      end

      let(:goals) { [root_goal_1, root_goal_2, child_1] }
      let(:query) { described_class.new(goals: goals) }

      it 'identifies both root goals' do
        expect(query.root_goals).to contain_exactly(root_goal_1, root_goal_2)
      end

      it 'only maps children for root_goal_1' do
        map = query.parent_child_map
        expect(map[root_goal_1.id]).to contain_exactly(child_1)
        expect(map[root_goal_2.id]).to be_empty
        expect(map[child_1.id]).to be_empty
      end
    end

    context 'with no links' do
      let!(:goal_1) { create(:goal, creator: teammate, owner: teammate) }
      let!(:goal_2) { create(:goal, creator: teammate, owner: teammate) }
      
      let(:goals) { [goal_1, goal_2] }
      let(:query) { described_class.new(goals: goals) }

      it 'identifies all goals as root goals' do
        expect(query.root_goals).to contain_exactly(goal_1, goal_2)
      end

      it 'has empty parent-child map' do
        map = query.parent_child_map
        expect(map[goal_1.id]).to be_empty
        expect(map[goal_2.id]).to be_empty
      end
    end

    context 'with goals outside the collection' do
      let!(:goal_14) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 14') }
      let!(:goal_15) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 15') }
      let!(:external_goal) { create(:goal, creator: teammate, owner: teammate, title: 'External') }
      
      let!(:link_14_to_15) do
        create(:goal_link,
               parent: goal_14,
               child: goal_15)
      end
      let!(:link_external_to_14) do
        create(:goal_link,
               parent: external_goal,
               child: goal_14)
      end

      let(:goals) { [goal_14, goal_15] }
      let(:query) { described_class.new(goals: goals) }

      it 'treats goal_14 as root since external_goal is not in collection' do
        expect(query.root_goals).to contain_exactly(goal_14)
      end

      it 'only includes links between goals in the collection' do
        result = query.call
        link_ids = result[:links].map(&:id)
        expect(link_ids).to include(link_14_to_15.id)
        expect(link_ids).not_to include(link_external_to_14.id)
      end
    end

    context 'with all links included' do
      let!(:goal_14) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 14') }
      let!(:goal_15) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 15') }
      
      let!(:link_14_to_15) do
        create(:goal_link,
               parent: goal_14,
               child: goal_15)
      end

      let(:goals) { [goal_14, goal_15] }
      let(:query) { described_class.new(goals: goals) }

      it 'includes all links' do
        result = query.call
        link_ids = result[:links].map(&:id)
        expect(link_ids).to include(link_14_to_15.id)
      end

      it 'builds hierarchy correctly' do
        expect(query.root_goals).to contain_exactly(goal_14)
        expect(query.parent_child_map[goal_14.id]).to contain_exactly(goal_15)
      end
    end
  end
end

