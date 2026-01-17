require 'rails_helper'

RSpec.describe Goals::ParseService, type: :service do
  let(:default_goal_type) { 'stepping_stone_activity' }

  describe '#initialize' do
    it 'sets instance variables correctly' do
      service = described_class.new("Goal 1\nGoal 2", default_goal_type)
      
      expect(service.textarea_content).to eq("Goal 1\nGoal 2")
      expect(service.default_goal_type).to eq(default_goal_type)
      expect(service.errors).to eq([])
    end
  end

  describe '#call' do
    context 'with simple goals (no nesting)' do
      it 'returns goals with default type' do
        content = "Goal 1\nGoal 2\nGoal 3"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(3)
        expect(result[:goals][0]).to include(
          title: 'Goal 1',
          goal_type: default_goal_type,
          parent_index: nil
        )
        expect(result[:goals][1]).to include(
          title: 'Goal 2',
          goal_type: default_goal_type,
          parent_index: nil
        )
        expect(result[:goals][2]).to include(
          title: 'Goal 3',
          goal_type: default_goal_type,
          parent_index: nil
        )
      end
    end

    context 'with dom followed by subs' do
      it 'makes dom an objective and links subs as children' do
        content = "Main Objective\n* Sub goal 1\n* Sub goal 2"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(3)
        expect(result[:goals][0]).to include(
          title: 'Main Objective',
          goal_type: 'inspirational_objective',
          parent_index: nil
        )
        expect(result[:goals][1]).to include(
          title: '* Sub goal 1',
          goal_type: default_goal_type,
          parent_index: 0
        )
        expect(result[:goals][2]).to include(
          title: '* Sub goal 2',
          goal_type: default_goal_type,
          parent_index: 0
        )
      end
    end

    context 'with multiple doms and subs' do
      it 'handles complex nesting correctly' do
        content = "Objective 1\n* Sub 1\n* Sub 2\nObjective 2\n- Sub 3\nStandalone"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(6)
        
        # Objective 1 with subs
        expect(result[:goals][0]).to include(
          title: 'Objective 1',
          goal_type: 'inspirational_objective',
          parent_index: nil
        )
        expect(result[:goals][1]).to include(
          title: '* Sub 1',
          goal_type: default_goal_type,
          parent_index: 0
        )
        expect(result[:goals][2]).to include(
          title: '* Sub 2',
          goal_type: default_goal_type,
          parent_index: 0
        )
        
        # Objective 2 with sub
        expect(result[:goals][3]).to include(
          title: 'Objective 2',
          goal_type: 'inspirational_objective',
          parent_index: nil
        )
        expect(result[:goals][4]).to include(
          title: '- Sub 3',
          goal_type: default_goal_type,
          parent_index: 3
        )
        
        # Standalone goal
        expect(result[:goals][5]).to include(
          title: 'Standalone',
          goal_type: default_goal_type,
          parent_index: nil
        )
      end
    end

    context 'with different sub indicators' do
      it 'recognizes all sub indicators' do
        content = "Objective\n1. Numbered\n* Starred\n• Bulleted\n- Hyphen\n– En dash\n.. Dotted"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(7)
        expect(result[:goals][0][:goal_type]).to eq('inspirational_objective')
        (1..6).each do |i|
          expect(result[:goals][i][:goal_type]).to eq(default_goal_type)
          expect(result[:goals][i][:parent_index]).to eq(0)
        end
      end
    end

    context 'with edge cases' do
      it 'handles sub at the start (treats as dom)' do
        content = "* Sub at start\nRegular goal"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(2)
        expect(result[:goals][0]).to include(
          title: '* Sub at start',
          goal_type: default_goal_type,
          parent_index: nil
        )
        expect(result[:goals][1]).to include(
          title: 'Regular goal',
          goal_type: default_goal_type,
          parent_index: nil
        )
      end

      it 'handles multiple consecutive subs without dom (links to previous dom)' do
        content = "First dom\n* Sub 1\n* Sub 2\n* Sub 3\nSecond dom"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(5)
        expect(result[:goals][0][:goal_type]).to eq('inspirational_objective')
        (1..3).each do |i|
          expect(result[:goals][i][:parent_index]).to eq(0)
        end
        expect(result[:goals][4][:goal_type]).to eq(default_goal_type)
      end

      it 'ignores empty lines' do
        content = "Goal 1\n\n\nGoal 2\n  \nGoal 3"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(3)
      end

      it 'preserves leading characters in titles' do
        content = "Objective\n* * Sub with star\n- - Sub with dash"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals][1][:title]).to eq('* * Sub with star')
        expect(result[:goals][2][:title]).to eq('- - Sub with dash')
      end

      it 'handles dots pattern (2 or more)' do
        content = "Objective\n.. Two dots\n... Three dots\n.... Four dots"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(4)
        (1..3).each do |i|
          expect(result[:goals][i][:parent_index]).to eq(0)
        end
      end
    end

    context 'with dom followed by dom' do
      it 'gives first dom default type' do
        content = "First dom\nSecond dom"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(2)
        expect(result[:goals][0]).to include(
          title: 'First dom',
          goal_type: default_goal_type,
          parent_index: nil
        )
        expect(result[:goals][1]).to include(
          title: 'Second dom',
          goal_type: default_goal_type,
          parent_index: nil
        )
      end
    end

    context 'with empty input' do
      it 'returns empty goals array' do
        service = described_class.new('', default_goal_type)
        
        result = service.call
        
        expect(result[:goals]).to eq([])
        expect(result[:errors]).to eq([])
      end

      it 'handles only whitespace' do
        service = described_class.new("   \n\n  ", default_goal_type)
        
        result = service.call
        
        expect(result[:goals]).to eq([])
        expect(result[:errors]).to eq([])
      end
    end

    context 'with different default goal types' do
      it 'uses provided default goal type for subs' do
        content = "Objective\n* Sub goal"
        service = described_class.new(content, 'quantitative_key_result')
        
        result = service.call
        
        expect(result[:goals][1][:goal_type]).to eq('quantitative_key_result')
      end
    end
  end
end
