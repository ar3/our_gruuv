require 'rails_helper'

RSpec.describe GoalLink, type: :model do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:creator_teammate) { create(:teammate, person: person, organization: company) }
  let(:goal1) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
  let(:goal2) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
  let(:goal3) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
  
  describe 'associations' do
    it { should belong_to(:parent).class_name('Goal') }
    it { should belong_to(:child).class_name('Goal') }
  end
  
  describe 'validations' do
    let(:goal_link) { build(:goal_link, parent: goal1, child: goal2) }
    
    it 'requires parent' do
      goal_link.parent = nil
      expect(goal_link).not_to be_valid
      expect(goal_link.errors[:parent]).to include("must exist")
    end
    
    it 'requires child' do
      goal_link.child = nil
      expect(goal_link).not_to be_valid
      expect(goal_link.errors[:child]).to include("must exist")
    end
    
    it 'prevents self-linking' do
      goal_link.parent = goal1
      goal_link.child = goal1
      expect(goal_link).not_to be_valid
      expect(goal_link.errors[:base]).to include("cannot link a goal to itself")
    end
    
    it 'allows linking different goals' do
      goal_link.parent = goal1
      goal_link.child = goal2
      expect(goal_link).to be_valid
    end
    
    it 'validates uniqueness of (parent_id, child_id)' do
      create(:goal_link, parent: goal1, child: goal2)
      duplicate_link = build(:goal_link, parent: goal1, child: goal2)
      
      expect(duplicate_link).not_to be_valid
      expect(duplicate_link.errors[:base]).to include("link already exists")
    end
    
    it 'allows same parent with different children' do
      create(:goal_link, parent: goal1, child: goal2)
      different_link = build(:goal_link, parent: goal1, child: goal3)
      
      expect(different_link).to be_valid
    end
    
    it 'allows same child with different parents' do
      create(:goal_link, parent: goal1, child: goal2)
      different_goals = build(:goal_link, parent: goal3, child: goal2)
      
      expect(different_goals).to be_valid
    end

    it 'prevents team/department/company goal as child of teammate goal' do
      org_owned_goal = create(:goal, creator: creator_teammate, company: company, owner: company, title: 'Company goal')
      link = build(:goal_link, parent: goal1, child: org_owned_goal)

      expect(link).not_to be_valid
      expect(link.errors[:base]).to include("A team, department, or company goal cannot be a child of a teammate goal")
    end

    it 'allows org-owned goal as parent of teammate goal' do
      org_owned_goal = create(:goal, creator: creator_teammate, company: company, owner: company, title: 'Company goal')
      link = build(:goal_link, parent: org_owned_goal, child: goal1)

      expect(link).to be_valid
    end
  end
  
  describe 'circular dependency prevention' do
    it 'prevents direct circular dependency' do
      create(:goal_link, parent: goal1, child: goal2)
      circular_link = build(:goal_link, parent: goal2, child: goal1)
      
      expect(circular_link).not_to be_valid
      expect(circular_link.errors[:base]).to include("This link would create a circular dependency")
    end
    
    it 'prevents transitive circular dependency' do
      # goal1 -> goal2 -> goal3, then try goal3 -> goal1
      create(:goal_link, parent: goal1, child: goal2)
      create(:goal_link, parent: goal2, child: goal3)
      circular_link = build(:goal_link, parent: goal3, child: goal1)
      
      expect(circular_link).not_to be_valid
      expect(circular_link.errors[:base]).to include("This link would create a circular dependency")
    end
    
    it 'prevents deeper transitive circular dependency' do
      # goal1 -> goal2 -> goal3 -> goal4, then try goal4 -> goal1
      goal4 = create(:goal, creator: creator_teammate, owner: creator_teammate)
      create(:goal_link, parent: goal1, child: goal2)
      create(:goal_link, parent: goal2, child: goal3)
      create(:goal_link, parent: goal3, child: goal4)
      circular_link = build(:goal_link, parent: goal4, child: goal1)
      
      expect(circular_link).not_to be_valid
      expect(circular_link.errors[:base]).to include("This link would create a circular dependency")
    end
    
    it 'prevents circular chains via back-links' do
      # goal1 -> goal2 -> goal3 (linear chain)
      create(:goal_link, parent: goal1, child: goal2)
      create(:goal_link, parent: goal2, child: goal3)
      # Adding goal3 -> goal2 creates a cycle: goal2 -> goal3 -> goal2
      circular_link = build(:goal_link, parent: goal3, child: goal2)
      
      # This should be invalid because it creates a cycle at goal2/goal3 level
      expect(circular_link).not_to be_valid
      expect(circular_link.errors[:base]).to include("This link would create a circular dependency")
    end
    
    it 'allows branching paths without cycles' do
      # goal1 -> goal2 and goal1 -> goal3 (branching, no cycle)
      create(:goal_link, parent: goal1, child: goal2)
      branching_link = build(:goal_link, parent: goal1, child: goal3)
      
      expect(branching_link).to be_valid
    end
  end
  
  describe 'metadata' do
    it 'stores metadata as jsonb hash' do
      link = create(:goal_link, 
        parent: goal1, 
        child: goal2,
        metadata: { notes: 'This is important', strength: 'high' }
      )
      
      expect(link.metadata).to eq({ 'notes' => 'This is important', 'strength' => 'high' })
    end
    
    it 'allows nil metadata' do
      link = build(:goal_link, parent: goal1, child: goal2, metadata: nil)
      expect(link).to be_valid
    end
    
    it 'allows empty hash metadata' do
      link = build(:goal_link, parent: goal1, child: goal2, metadata: {})
      expect(link).to be_valid
    end
  end
end



