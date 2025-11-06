require 'rails_helper'

RSpec.describe GoalLink, type: :model do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:creator_teammate) { create(:teammate, person: person, organization: company) }
  let(:goal1) { create(:goal, creator: creator_teammate, owner: person) }
  let(:goal2) { create(:goal, creator: creator_teammate, owner: person) }
  let(:goal3) { create(:goal, creator: creator_teammate, owner: person) }
  
  describe 'associations' do
    it { should belong_to(:this_goal).class_name('Goal') }
    it { should belong_to(:that_goal).class_name('Goal') }
  end
  
  describe 'enums' do
    it 'defines link_type enum' do
      expect(GoalLink.link_types).to eq({
        'if_this_then_that' => 'if_this_then_that',
        'this_blocks_that' => 'this_blocks_that',
        'this_makes_that_easier' => 'this_makes_that_easier',
        'this_makes_that_unnecessary' => 'this_makes_that_unnecessary',
        'this_is_key_result_of_that' => 'this_is_key_result_of_that',
        'this_supports_that' => 'this_supports_that'
      })
    end
  end
  
  describe 'validations' do
    let(:goal_link) { build(:goal_link, this_goal: goal1, that_goal: goal2) }
    
    it 'requires this_goal' do
      goal_link.this_goal = nil
      expect(goal_link).not_to be_valid
      expect(goal_link.errors[:this_goal]).to include("must exist")
    end
    
    it 'requires that_goal' do
      goal_link.that_goal = nil
      expect(goal_link).not_to be_valid
      expect(goal_link.errors[:that_goal]).to include("must exist")
    end
    
    it 'requires link_type' do
      goal_link.link_type = nil
      expect(goal_link).not_to be_valid
      expect(goal_link.errors[:link_type]).to include("can't be blank")
    end
    
    it 'validates link_type inclusion' do
      # Rails enum raises ArgumentError when setting invalid value via assignment
      # This is the expected behavior - enums validate at assignment time
      expect {
        goal_link.link_type = 'invalid_type'
      }.to raise_error(ArgumentError, "'invalid_type' is not a valid link_type")
    end
    
    it 'prevents self-linking' do
      goal_link.this_goal = goal1
      goal_link.that_goal = goal1
      expect(goal_link).not_to be_valid
      expect(goal_link.errors[:base]).to include("cannot link a goal to itself")
    end
    
    it 'allows linking different goals' do
      goal_link.this_goal = goal1
      goal_link.that_goal = goal2
      expect(goal_link).to be_valid
    end
    
    it 'validates uniqueness of (this_goal_id, that_goal_id, link_type)' do
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      duplicate_link = build(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      
      expect(duplicate_link).not_to be_valid
      expect(duplicate_link.errors[:base]).to include("link already exists")
    end
    
    it 'allows same goals with different link_types' do
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      different_link = build(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_supports_that')
      
      expect(different_link).to be_valid
    end
    
    it 'allows same link_type between different goals' do
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      different_goals = build(:goal_link, this_goal: goal2, that_goal: goal3, link_type: 'this_blocks_that')
      
      expect(different_goals).to be_valid
    end
  end
  
  describe 'circular dependency prevention' do
    it 'prevents direct circular dependency' do
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      circular_link = build(:goal_link, this_goal: goal2, that_goal: goal1, link_type: 'this_blocks_that')
      
      expect(circular_link).not_to be_valid
      expect(circular_link.errors[:base]).to include("This link would create a circular dependency")
    end
    
    it 'prevents transitive circular dependency' do
      # goal1 -> goal2 -> goal3, then try goal3 -> goal1
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      create(:goal_link, this_goal: goal2, that_goal: goal3, link_type: 'this_blocks_that')
      circular_link = build(:goal_link, this_goal: goal3, that_goal: goal1, link_type: 'this_blocks_that')
      
      expect(circular_link).not_to be_valid
      expect(circular_link.errors[:base]).to include("This link would create a circular dependency")
    end
    
    it 'prevents deeper transitive circular dependency' do
      # goal1 -> goal2 -> goal3 -> goal4, then try goal4 -> goal1
      goal4 = create(:goal, creator: creator_teammate, owner: person)
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      create(:goal_link, this_goal: goal2, that_goal: goal3, link_type: 'this_blocks_that')
      create(:goal_link, this_goal: goal3, that_goal: goal4, link_type: 'this_blocks_that')
      circular_link = build(:goal_link, this_goal: goal4, that_goal: goal1, link_type: 'this_blocks_that')
      
      expect(circular_link).not_to be_valid
      expect(circular_link.errors[:base]).to include("This link would create a circular dependency")
    end
    
    it 'prevents circular chains via back-links' do
      # goal1 -> goal2 -> goal3 (linear chain)
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      create(:goal_link, this_goal: goal2, that_goal: goal3, link_type: 'this_blocks_that')
      # Adding goal3 -> goal2 creates a cycle: goal2 -> goal3 -> goal2
      circular_link = build(:goal_link, this_goal: goal3, that_goal: goal2, link_type: 'this_makes_that_easier')
      
      # This should be invalid because it creates a cycle at goal2/goal3 level
      expect(circular_link).not_to be_valid
      expect(circular_link.errors[:base]).to include("This link would create a circular dependency")
    end
    
    it 'allows branching paths without cycles' do
      # goal1 -> goal2 and goal1 -> goal3 (branching, no cycle)
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      branching_link = build(:goal_link, this_goal: goal1, that_goal: goal3, link_type: 'this_supports_that')
      
      expect(branching_link).to be_valid
    end
  end
  
  describe 'metadata' do
    it 'stores metadata as jsonb hash' do
      link = create(:goal_link, 
        this_goal: goal1, 
        that_goal: goal2,
        metadata: { notes: 'This is important', strength: 'high' }
      )
      
      expect(link.metadata).to eq({ 'notes' => 'This is important', 'strength' => 'high' })
    end
    
    it 'allows nil metadata' do
      link = build(:goal_link, this_goal: goal1, that_goal: goal2, metadata: nil)
      expect(link).to be_valid
    end
    
    it 'allows empty hash metadata' do
      link = build(:goal_link, this_goal: goal1, that_goal: goal2, metadata: {})
      expect(link).to be_valid
    end
  end
end



