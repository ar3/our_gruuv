require 'rails_helper'

RSpec.describe Goals::HierarchyWithCheckInsQuery do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: company) }
  let(:person) { teammate.person }

  describe '#call' do
    context 'with the structure: Goal 14 -> [15, 16], Goal 16 -> [18]' do
      let!(:goal_14) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 14', most_likely_target_date: Date.today + 30.days, started_at: Time.current) }
      let!(:goal_15) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 15', most_likely_target_date: Date.today + 30.days, started_at: Time.current) }
      let!(:goal_16) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 16', most_likely_target_date: Date.today + 30.days, started_at: Time.current) }
      let!(:goal_18) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 18', most_likely_target_date: Date.today + 30.days, started_at: Time.current) }

      let!(:link_14_to_15) { create(:goal_link, parent: goal_14, child: goal_15) }
      let!(:link_14_to_16) { create(:goal_link, parent: goal_14, child: goal_16) }
      let!(:link_16_to_18) { create(:goal_link, parent: goal_16, child: goal_18) }

      let(:goals) { [goal_14, goal_15, goal_16, goal_18] }
      let(:query) { described_class.new(goals: goals, current_person: person, organization: company) }

      it 'returns enriched hierarchy with root_goals' do
        result = query.call
        expect(result[:root_goals].length).to eq(1)
        expect(result[:root_goals].first[:goal]).to eq(goal_14)
      end

      it 'calculates direct_children_count correctly' do
        result = query.call
        root_node = result[:root_goals].first
        
        # Goal 14 has 2 direct children (15 and 16)
        expect(root_node[:direct_children_count]).to eq(2)
      end

      it 'calculates total_descendants_count correctly' do
        result = query.call
        root_node = result[:root_goals].first
        
        # Goal 14 has 3 total descendants (15, 16, 18)
        expect(root_node[:total_descendants_count]).to eq(3)
      end

      it 'recursively builds children nodes' do
        result = query.call
        root_node = result[:root_goals].first
        
        # Find goal_16 child node
        goal_16_node = root_node[:children].find { |c| c[:goal] == goal_16 }
        expect(goal_16_node).to be_present
        expect(goal_16_node[:direct_children_count]).to eq(1)
        expect(goal_16_node[:total_descendants_count]).to eq(1)
        expect(goal_16_node[:children].first[:goal]).to eq(goal_18)
      end
    end

    context 'with check-ins' do
      let!(:goal) { create(:goal, creator: teammate, owner: teammate, title: 'Goal with check-in', most_likely_target_date: Date.today + 30.days, started_at: Time.current) }
      let!(:check_in) { create(:goal_check_in, goal: goal, confidence_percentage: 50, confidence_reporter: person, check_in_week_start: Date.current.beginning_of_week(:monday)) }

      let(:goals) { [goal] }
      let(:query) { described_class.new(goals: goals, current_person: person, organization: company) }

      it 'includes most_recent_check_in in node' do
        result = query.call
        node = result[:root_goals].first
        expect(node[:most_recent_check_in]).to eq(check_in)
      end

      it 'includes current_week_check_in in node' do
        result = query.call
        node = result[:root_goals].first
        expect(node[:current_week_check_in]).to eq(check_in)
      end

      it 'returns most_recent_check_ins_by_goal map' do
        result = query.call
        expect(result[:most_recent_check_ins_by_goal][goal.id]).to eq(check_in)
      end

      it 'returns current_week_check_ins_by_goal map' do
        result = query.call
        expect(result[:current_week_check_ins_by_goal][goal.id]).to eq(check_in)
      end
    end

    context 'with permissions' do
      let!(:goal) { create(:goal, creator: teammate, owner: teammate, title: 'Viewable Goal', privacy_level: 'everyone_in_company') }
      let(:goals) { [goal] }
      let(:query) { described_class.new(goals: goals, current_person: person, organization: company) }

      it 'includes can_check_in flag when person can view goal' do
        result = query.call
        node = result[:root_goals].first
        expect(node[:can_check_in]).to be(true)
      end

      it 'returns can_check_in_goals set' do
        result = query.call
        expect(result[:can_check_in_goals]).to include(goal.id)
      end

      context 'with restricted privacy' do
        let(:other_person) { create(:person) }
        let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
        let!(:private_goal) { create(:goal, creator: teammate, owner: teammate, title: 'Private Goal', privacy_level: 'only_creator') }
        let(:goals) { [private_goal] }
        let(:query) { described_class.new(goals: goals, current_person: other_person, organization: company) }

        it 'does not include can_check_in for goals user cannot view' do
          result = query.call
          expect(result[:can_check_in_goals]).not_to include(private_goal.id)
        end
      end
    end

    context 'without current_person' do
      let!(:goal) { create(:goal, creator: teammate, owner: teammate, title: 'Goal') }
      let(:goals) { [goal] }
      let(:query) { described_class.new(goals: goals, current_person: nil, organization: company) }

      it 'returns empty can_check_in_goals set' do
        result = query.call
        expect(result[:can_check_in_goals]).to be_empty
      end
    end

    context 'with no goals' do
      let(:goals) { [] }
      let(:query) { described_class.new(goals: goals, current_person: person, organization: company) }

      it 'returns empty root_goals' do
        result = query.call
        expect(result[:root_goals]).to be_empty
      end

      it 'returns empty maps' do
        result = query.call
        expect(result[:most_recent_check_ins_by_goal]).to be_empty
        expect(result[:current_week_check_ins_by_goal]).to be_empty
        expect(result[:can_check_in_goals]).to be_empty
      end
    end
  end
end
