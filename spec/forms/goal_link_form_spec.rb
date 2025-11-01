require 'rails_helper'

RSpec.describe GoalLinkForm, type: :form do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:creator_teammate) { create(:teammate, person: person, organization: company) }
  let(:goal1) { create(:goal, creator: creator_teammate, owner: person) }
  let(:goal2) { create(:goal, creator: creator_teammate, owner: person) }
  let(:goal3) { create(:goal, creator: creator_teammate, owner: person) }
  let(:goal_link) { build(:goal_link, this_goal: goal1, that_goal: goal2) }
  let(:form) { GoalLinkForm.new(goal_link) }
  
  describe 'validations' do
    it 'requires this_goal_id' do
      form.this_goal_id = nil
      expect(form).not_to be_valid
      expect(form.errors[:this_goal_id]).to include("can't be blank")
    end
    
    it 'requires that_goal_id' do
      form.that_goal_id = nil
      expect(form).not_to be_valid
      expect(form.errors[:that_goal_id]).to include("can't be blank")
    end
    
    it 'requires link_type' do
      form.link_type = nil
      expect(form).not_to be_valid
      expect(form.errors[:link_type]).to include("can't be blank")
    end
    
    it 'validates link_type inclusion' do
      form.link_type = 'invalid_type'
      expect(form).not_to be_valid
      expect(form.errors[:link_type]).to include('is not included in the list')
    end
    
    it 'prevents self-linking' do
      form.this_goal_id = goal1.id
      form.that_goal_id = goal1.id
      form.link_type = 'this_blocks_that'
      
      expect(form).not_to be_valid
      expect(form.errors[:base]).to include("cannot link a goal to itself")
    end
    
    it 'allows linking different goals' do
      form.this_goal_id = goal1.id
      form.that_goal_id = goal2.id
      form.link_type = 'this_blocks_that'
      
      expect(form).to be_valid
    end
    
    it 'validates uniqueness of (this_goal_id, that_goal_id, link_type)' do
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      form.this_goal_id = goal1.id
      form.that_goal_id = goal2.id
      form.link_type = 'this_blocks_that'
      
      expect(form).not_to be_valid
      expect(form.errors[:base]).to include("link already exists")
    end
    
    it 'allows same goals with different link_types' do
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      form.this_goal_id = goal1.id
      form.that_goal_id = goal2.id
      form.link_type = 'this_supports_that'
      
      expect(form).to be_valid
    end
    
    it 'prevents circular dependencies' do
      # Create goal1 -> goal2
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      
      # Try to create goal2 -> goal1 (direct circular dependency)
      form.this_goal_id = goal2.id
      form.that_goal_id = goal1.id
      form.link_type = 'this_blocks_that'
      
      expect(form).not_to be_valid
      expect(form.errors[:base]).to include("This link would create a circular dependency")
    end
    
    it 'prevents transitive circular dependencies' do
      # Create goal1 -> goal2 -> goal3
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      create(:goal_link, this_goal: goal2, that_goal: goal3, link_type: 'this_blocks_that')
      
      # Try to create goal3 -> goal1 (transitive circular dependency)
      form.this_goal_id = goal3.id
      form.that_goal_id = goal1.id
      form.link_type = 'this_blocks_that'
      
      expect(form).not_to be_valid
      expect(form.errors[:base]).to include("This link would create a circular dependency")
    end
    
    it 'allows non-circular chains' do
      # Create goal1 -> goal2
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      
      # Create goal2 -> goal3 (linear chain, no cycle)
      form.this_goal_id = goal2.id
      form.that_goal_id = goal3.id
      form.link_type = 'this_blocks_that'
      
      expect(form).to be_valid
    end
  end
  
  describe 'save method' do
    it 'creates goal link with valid attributes' do
      form.this_goal_id = goal1.id
      form.that_goal_id = goal2.id
      form.link_type = 'this_blocks_that'
      
      expect(form.save).to be true
      expect(goal_link.this_goal).to eq(goal1)
      expect(goal_link.that_goal).to eq(goal2)
      expect(goal_link.link_type).to eq('this_blocks_that')
    end
    
    it 'handles metadata' do
      form.this_goal_id = goal1.id
      form.that_goal_id = goal2.id
      form.link_type = 'this_supports_that'
      form.metadata = { notes: 'Important link', strength: 'high' }
      
      expect(form.save).to be true
      expect(goal_link.metadata).to eq({ 'notes' => 'Important link', 'strength' => 'high' })
    end
    
    it 'allows nil metadata' do
      form.this_goal_id = goal1.id
      form.that_goal_id = goal2.id
      form.link_type = 'this_makes_that_easier'
      form.metadata = nil
      
      expect(form.save).to be true
      expect(goal_link.metadata).to be_nil
    end
    
    it 'does not save if invalid' do
      form.this_goal_id = nil
      form.that_goal_id = goal2.id
      form.link_type = 'this_blocks_that'
      
      expect(form.save).to be false
      expect(goal_link).not_to be_persisted
    end
  end
end

