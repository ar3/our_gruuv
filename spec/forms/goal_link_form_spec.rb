require 'rails_helper'

RSpec.describe GoalLinkForm, type: :form do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:creator_teammate) { create(:teammate, person: person, organization: company) }
  let(:goal1) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
  let(:goal2) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
  let(:goal3) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
  let(:goal_link) { build(:goal_link, this_goal: goal1, that_goal: goal2) }
  let(:form) { GoalLinkForm.new(goal_link) }
  
  describe 'validations' do
    it 'requires link_type' do
      form.link_type = nil
      form.link_direction = 'outgoing'
      expect(form).not_to be_valid
      expect(form.errors[:link_type]).to include("can't be blank")
    end
    
    it 'requires link_direction' do
      form.link_type = 'this_blocks_that'
      form.link_direction = nil
      expect(form).not_to be_valid
      expect(form.errors[:link_direction]).to include("can't be blank")
    end
    
    it 'validates link_direction inclusion' do
      form.link_direction = 'invalid'
      form.link_type = 'this_blocks_that'
      expect(form).not_to be_valid
      expect(form.errors[:link_direction]).to be_present
    end
    
    context 'with outgoing direction and existing goal mode' do
      before do
        form.link_direction = 'outgoing'
        form.bulk_create_mode = false
        form.linking_goal = goal1
      end
      
      it 'requires that_goal_id' do
        form.that_goal_id = nil
        form.link_type = 'this_blocks_that'
        expect(form).not_to be_valid
        expect(form.errors[:that_goal_id]).to include("can't be blank")
      end
    end
    
    context 'with incoming direction and existing goal mode' do
      before do
        form.link_direction = 'incoming'
        form.bulk_create_mode = false
        form.linking_goal = goal1
      end
      
      it 'requires this_goal_id' do
        form.this_goal_id = nil
        form.link_type = 'this_blocks_that'
        expect(form).not_to be_valid
        expect(form.errors[:this_goal_id]).to include("can't be blank")
      end
    end
    
    context 'with bulk create mode' do
      before do
        form.link_direction = 'outgoing'
        form.bulk_create_mode = true
        form.linking_goal = goal1
        form.organization = company
        form.current_person = person
        form.current_teammate = creator_teammate
      end
      
      it 'requires bulk_goal_titles' do
        form.bulk_goal_titles = nil
        form.link_type = 'this_is_key_result_of_that'
        expect(form).not_to be_valid
        expect(form.errors[:bulk_goal_titles]).to include("can't be blank")
      end
      
      it 'requires at least one non-blank title' do
        form.bulk_goal_titles = "\n  \n"
        form.link_type = 'this_is_key_result_of_that'
        expect(form).not_to be_valid
        # May show "can't be blank" or "must contain at least one goal title"
        expect(form.errors[:bulk_goal_titles]).not_to be_empty
      end
      
      it 'allows bulk_goal_titles with content' do
        form.bulk_goal_titles = "Goal 1\nGoal 2"
        form.link_type = 'this_is_key_result_of_that'
        expect(form).to be_valid
      end
    end
    
    it 'validates link_type inclusion' do
      form.link_type = 'invalid_type'
      expect(form).not_to be_valid
      expect(form.errors[:link_type]).to include('is not included in the list')
    end
    
    context 'with outgoing direction' do
      before do
        form.link_direction = 'outgoing'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'prevents self-linking' do
        form.that_goal_id = goal1.id
        form.link_type = 'this_blocks_that'
        
        expect(form).not_to be_valid
        expect(form.errors[:base]).to include("cannot link a goal to itself")
      end
    end
    
    context 'with incoming direction' do
      before do
        form.link_direction = 'incoming'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'prevents self-linking' do
        form.this_goal_id = goal1.id
        form.link_type = 'this_blocks_that'
        
        expect(form).not_to be_valid
        expect(form.errors[:base]).to include("cannot link a goal to itself")
      end
    end
    
    context 'with outgoing direction' do
      before do
        form.link_direction = 'outgoing'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'allows linking different goals' do
        form.that_goal_id = goal2.id
        form.link_type = 'this_blocks_that'
        
        expect(form).to be_valid
      end
    end
    
    context 'with incoming direction' do
      before do
        form.link_direction = 'incoming'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'allows linking different goals' do
        form.this_goal_id = goal2.id
        form.link_type = 'this_blocks_that'
        
        expect(form).to be_valid
      end
    end
    
    context 'with outgoing direction' do
      before do
        form.link_direction = 'outgoing'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'validates uniqueness of (this_goal_id, that_goal_id, link_type)' do
        create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
        form.that_goal_id = goal2.id
        form.link_type = 'this_blocks_that'
        
        expect(form).not_to be_valid
        expect(form.errors[:base]).to include("link already exists")
      end
      
      it 'allows same goals with different link_types' do
        create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
        form.that_goal_id = goal2.id
        form.link_type = 'this_supports_that'
        
        expect(form).to be_valid
      end
    end
    
    context 'with outgoing direction' do
      before do
        form.link_direction = 'outgoing'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'prevents circular dependencies' do
        # Create goal1 -> goal2
        create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
        
        # Try to create goal2 -> goal1 (direct circular dependency)
        form.that_goal_id = goal2.id
        form.link_type = 'this_blocks_that'
        
        # Then try to create goal2 -> goal1 through incoming direction
        form2 = GoalLinkForm.new(build(:goal_link))
        form2.link_direction = 'outgoing'
        form2.linking_goal = goal2
        form2.bulk_create_mode = false
        form2.that_goal_id = goal1.id
        form2.link_type = 'this_blocks_that'
        
        expect(form2).not_to be_valid
        expect(form2.errors[:base]).to include("This link would create a circular dependency")
      end
      
      it 'prevents transitive circular dependencies' do
        # Create goal1 -> goal2 -> goal3
        create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
        create(:goal_link, this_goal: goal2, that_goal: goal3, link_type: 'this_blocks_that')
        
        # Try to create goal3 -> goal1 (transitive circular dependency)
        form.that_goal_id = goal3.id
        form.link_type = 'this_blocks_that'
        
        form3 = GoalLinkForm.new(build(:goal_link))
        form3.link_direction = 'outgoing'
        form3.linking_goal = goal3
        form3.bulk_create_mode = false
        form3.that_goal_id = goal1.id
        form3.link_type = 'this_blocks_that'
        
        expect(form3).not_to be_valid
        expect(form3.errors[:base]).to include("This link would create a circular dependency")
      end
      
      it 'allows non-circular chains' do
        # Create goal1 -> goal2
        create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
        
        # Create goal2 -> goal3 (linear chain, no cycle)
        form.that_goal_id = goal3.id
        form.link_type = 'this_blocks_that'
        
        form2 = GoalLinkForm.new(build(:goal_link))
        form2.link_direction = 'outgoing'
        form2.linking_goal = goal2
        form2.bulk_create_mode = false
        form2.that_goal_id = goal3.id
        form2.link_type = 'this_blocks_that'
        
        expect(form2).to be_valid
      end
    end
  end
  
  describe 'save method' do
    context 'with outgoing direction' do
      before do
        form.link_direction = 'outgoing'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'creates goal link with valid attributes' do
        form.that_goal_id = goal2.id
        form.link_type = 'this_blocks_that'
        
        expect(form.save).to be true
        expect(goal_link.this_goal).to eq(goal1)
        expect(goal_link.that_goal).to eq(goal2)
        expect(goal_link.link_type).to eq('this_blocks_that')
      end
    end
    
    context 'with incoming direction' do
      before do
        form.link_direction = 'incoming'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'creates goal link with valid attributes' do
        form.this_goal_id = goal2.id
        form.link_type = 'this_is_key_result_of_that'
        
        expect(form.save).to be true
        expect(goal_link.this_goal).to eq(goal2)
        expect(goal_link.that_goal).to eq(goal1)
        expect(goal_link.link_type).to eq('this_is_key_result_of_that')
      end
    end
    
    context 'with bulk create mode' do
      let(:organization) { company }
      let(:current_person) { person }
      let(:current_teammate) { creator_teammate }
      
      before do
        form.link_direction = 'outgoing'
        form.bulk_create_mode = true
        form.linking_goal = goal1
        form.organization = organization
        form.current_person = current_person
        form.current_teammate = current_teammate
      end
      
      it 'creates multiple goals via bulk service' do
        form.bulk_goal_titles = "New Goal 1\nNew Goal 2"
        form.link_type = 'this_is_key_result_of_that'
        
        expect { form.save }.to change { Goal.count }.by(2)
        expect(form.save).to be true
        
        created_goals = Goal.last(2)
        created_goals.each do |goal|
          expect(goal.goal_type).to eq('quantitative_key_result')
          expect(goal.owner).to be_a(Teammate)
          expect(goal.owner.id).to eq(goal1.owner.id)
          expect(goal.privacy_level).to eq(goal1.privacy_level)
          
          link = GoalLink.find_by(this_goal: goal1, that_goal: goal, link_type: 'this_is_key_result_of_that')
          expect(link).to be_present
        end
      end
      
      it 'creates goals as inspirational_objective for incoming links' do
        form.link_direction = 'incoming'
        form.bulk_goal_titles = "New Goal 1"
        form.link_type = 'this_is_key_result_of_that'
        
        expect { form.save }.to change { Goal.count }.by(1)
        expect(form.save).to be true
        
        created_goal = Goal.last
        expect(created_goal.goal_type).to eq('inspirational_objective')
        
        link = GoalLink.find_by(this_goal: created_goal, that_goal: goal1, link_type: 'this_is_key_result_of_that')
        expect(link).to be_present
      end
      
      it 'handles bulk service errors' do
        allow_any_instance_of(Goals::BulkCreateService).to receive(:call).and_return(false)
        allow_any_instance_of(Goals::BulkCreateService).to receive(:errors).and_return(['Error creating goal'])
        
        form.bulk_goal_titles = "New Goal 1"
        form.link_type = 'this_is_key_result_of_that'
        
        expect(form.save).to be false
        expect(form.errors[:base]).to include('Error creating goal')
      end
    end
    
    context 'with outgoing direction' do
      before do
        form.link_direction = 'outgoing'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'handles metadata' do
        form.that_goal_id = goal2.id
        form.link_type = 'this_supports_that'
        form.metadata = { notes: 'Important link', strength: 'high' }
        
        expect(form.save).to be true
        expect(goal_link.metadata).to eq({ 'notes' => 'Important link', 'strength' => 'high' })
      end
      
      it 'allows nil metadata' do
        form.that_goal_id = goal2.id
        form.link_type = 'this_makes_that_easier'
        form.metadata = nil
        
        expect(form.save).to be true
        expect(goal_link.metadata).to be_nil
      end
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


