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
        content = "Objective\n1. Numbered\n* Starred\n• Bulleted\n- Hyphen\n– En dash\n.. Dotted\nA. Letter\nb) Letter paren\nii. Roman\nIII) Roman paren\n  Two spaces"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(12)
        expect(result[:goals][0][:goal_type]).to eq('inspirational_objective')
        (1..10).each do |i|
          expect(result[:goals][i][:goal_type]).to eq(default_goal_type)
          expect(result[:goals][i][:parent_index]).to eq(0)
        end
        # "  Two spaces" has 2+ more leading spaces than previous sub → sub-sub of goal 10
        expect(result[:goals][11][:goal_type]).to eq(default_goal_type)
        expect(result[:goals][11][:parent_index]).to eq(10)
      end
    end

    context 'with letter, roman numeral, and space sub indicators' do
      it 'recognizes A., b), ii., III), and 2+ leading spaces; indented line is sub-sub of previous' do
        content = "Objective\nA. First\nb) Second\nii. Third\nIII) Fourth\n  Indented sub"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(6)
        expect(result[:goals][0]).to include(
          title: 'Objective',
          goal_type: 'inspirational_objective',
          parent_index: nil
        )
        (1..4).each do |i|
          expect(result[:goals][i][:goal_type]).to eq(default_goal_type)
          expect(result[:goals][i][:parent_index]).to eq(0)
        end
        expect(result[:goals][1][:title]).to eq('A. First')
        expect(result[:goals][2][:title]).to eq('b) Second')
        expect(result[:goals][3][:title]).to eq('ii. Third')
        expect(result[:goals][4][:title]).to eq('III) Fourth')
        expect(result[:goals][5][:title]).to eq('Indented sub')
        expect(result[:goals][5][:parent_index]).to eq(4)
      end
    end

    context 'with sub-sub goals by indentation' do
      it 'makes a sub a child of the previous sub when it has 2+ more leading spaces' do
        content = "Objective\n  Sub one\n    Sub-sub of one\n  Sub two"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(4)
        expect(result[:goals][0]).to include(
          title: 'Objective',
          goal_type: 'inspirational_objective',
          parent_index: nil
        )
        expect(result[:goals][1]).to include(
          title: 'Sub one',
          goal_type: default_goal_type,
          parent_index: 0
        )
        expect(result[:goals][2]).to include(
          title: 'Sub-sub of one',
          goal_type: default_goal_type,
          parent_index: 1
        )
        expect(result[:goals][3]).to include(
          title: 'Sub two',
          goal_type: default_goal_type,
          parent_index: 0
        )
      end
    end

    context 'with complex real-world hierarchy (siblings and nested subs)' do
      it 'makes same-indentation subs siblings under the same parent; deeper indent under previous sub' do
        content = <<~TEXT.strip
          Become an Avenger
          1. Find a spider to be bitten by
          2. Learn the "thwip" the spider web
          3. Find partner
            - decide if I want Mary Jane or Gwen
            - evaluate them on their ability to help me deal with the devastation of my cannon event
          4. Yeah, there is the Uncle Ben or equivalent thing
            i) They have to tell me "with great power comes great responsibility"
            ii) Then they have to... ummm... well it is sad
            iii) Then I have to grieve
              * Grieving without turning into a villain is vital
          5. Then I have to be the friendly neighborhood spidey
          6. Them meet Tony
          7. Then Save the freakin universe baby!
          Improve my time management
          * Try pomodoro
          * Evaluate all meetings on my calendar
        TEXT
        service = described_class.new(content, default_goal_type)
        result = service.call

        expect(result[:errors]).to be_empty
        goals = result[:goals]

        # First dom: Become an Avenger (0)
        expect(goals[0][:title]).to eq('Become an Avenger')
        expect(goals[0][:parent_index]).to be_nil

        # 1. 2. 3. are direct subs of objective (indices 1, 2, 3)
        expect(goals[1][:parent_index]).to eq(0)
        expect(goals[2][:parent_index]).to eq(0)
        expect(goals[3][:parent_index]).to eq(0)
        expect(goals[3][:title]).to include('Find partner')

        # Two 2-space bullets under "3. Find partner": siblings, both parent 3
        expect(goals[4][:title]).to include('decide if I want Mary Jane or Gwen')
        expect(goals[4][:parent_index]).to eq(3)
        expect(goals[5][:title]).to include('evaluate them on their ability')
        expect(goals[5][:parent_index]).to eq(3)

        # "4. Yeah..." is back under objective (0)
        expect(goals[6][:title]).to include('Uncle Ben or equivalent')
        expect(goals[6][:parent_index]).to eq(0)

        # i) ii) iii) under "4. Yeah" (siblings, parent 6)
        expect(goals[7][:parent_index]).to eq(6)
        expect(goals[8][:parent_index]).to eq(6)
        expect(goals[9][:parent_index]).to eq(6)

        # "* Grieving without..." is 4 spaces, under iii) (goal 9)
        expect(goals[10][:title]).to include('Grieving without turning')
        expect(goals[10][:parent_index]).to eq(9)

        # 5. 6. 7. under objective
        expect(goals[11][:parent_index]).to eq(0)
        expect(goals[12][:parent_index]).to eq(0)
        expect(goals[13][:parent_index]).to eq(0)

        # Second dom: Improve my time management (14)
        expect(goals[14][:title]).to eq('Improve my time management')
        expect(goals[14][:parent_index]).to be_nil

        # Two bullets under second dom
        expect(goals[15][:parent_index]).to eq(14)
        expect(goals[16][:parent_index]).to eq(14)
      end
    end

    context 'with leading spaces in input' do
      it 'strips leading spaces from stored titles' do
        content = "Objective\n  A. Indented letter\n    Four space sub"
        service = described_class.new(content, default_goal_type)
        
        result = service.call
        
        expect(result[:errors]).to be_empty
        expect(result[:goals].length).to eq(3)
        expect(result[:goals][0][:title]).to eq('Objective')
        expect(result[:goals][1][:title]).to eq('A. Indented letter')
        expect(result[:goals][2][:title]).to eq('Four space sub')
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
