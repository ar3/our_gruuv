require 'rails_helper'

RSpec.describe GoalLinkForm, type: :form do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:creator_teammate) { create(:teammate, person: person, organization: company) }
  let(:goal1) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
  let(:goal2) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
  let(:goal3) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
  let(:goal_link) { build(:goal_link, parent: goal1, child: goal2) }
  let(:form) { GoalLinkForm.new(goal_link) }
  
  describe 'validations' do
    it 'requires link_direction' do
      form.link_direction = nil
      expect(form).not_to be_valid
      expect(form.errors[:link_direction]).to include("can't be blank")
    end
    
    it 'validates link_direction inclusion' do
      form.link_direction = 'invalid'
      expect(form).not_to be_valid
      expect(form.errors[:link_direction]).to be_present
    end
    
    context 'with outgoing direction and existing goal mode' do
      before do
        form.link_direction = 'outgoing'
        form.bulk_create_mode = false
        form.linking_goal = goal1
      end
      
      it 'requires child_id' do
        form.child_id = nil
        expect(form).not_to be_valid
        expect(form.errors[:child_id]).to include("can't be blank")
      end
    end
    
    context 'with incoming direction and existing goal mode' do
      before do
        form.link_direction = 'incoming'
        form.bulk_create_mode = false
        form.linking_goal = goal1
      end
      
      it 'requires parent_id' do
        form.parent_id = nil
        expect(form).not_to be_valid
        expect(form.errors[:parent_id]).to include("can't be blank")
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
        expect(form).not_to be_valid
        expect(form.errors[:bulk_goal_titles]).to include("can't be blank")
      end
      
      it 'requires at least one non-blank title' do
        form.bulk_goal_titles = "\n  \n"
        expect(form).not_to be_valid
        # May show "can't be blank" or "must contain at least one goal title"
        expect(form.errors[:bulk_goal_titles]).not_to be_empty
      end
      
      it 'allows bulk_goal_titles with content' do
        form.bulk_goal_titles = "Goal 1\nGoal 2"
        expect(form).to be_valid
      end
    end
    
    
    context 'with outgoing direction' do
      before do
        form.link_direction = 'outgoing'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'prevents self-linking' do
        form.child_id = goal1.id
        
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
        form.parent_id = goal1.id
        
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
        form.child_id = goal2.id
        
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
        form.parent_id = goal2.id
        
        expect(form).to be_valid
      end
    end
    
    context 'with outgoing direction' do
      before do
        form.link_direction = 'outgoing'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'validates uniqueness of (parent_id, child_id)' do
        create(:goal_link, parent: goal1, child: goal2)
        form.child_id = goal2.id
        
        expect(form).not_to be_valid
        expect(form.errors[:base]).to include("link already exists")
      end
    end

    context 'teammate parent / org-dept-team child' do
      let(:org_owned_goal) { create(:goal, creator: creator_teammate, owner: company, company: company, title: 'Company goal') }

      it 'rejects linking an org/company goal as child of a teammate goal (outgoing)' do
        form.link_direction = 'outgoing'
        form.linking_goal = goal1
        form.child_id = org_owned_goal.id
        form.bulk_create_mode = false

        expect(form).not_to be_valid
        expect(form.errors[:base]).to include("A team, department, or company goal cannot be a child of a teammate goal")
      end

      it 'rejects linking a teammate goal as parent when child is org-owned (incoming)' do
        form.link_direction = 'incoming'
        form.linking_goal = org_owned_goal
        form.parent_id = goal1.id
        form.bulk_create_mode = false

        expect(form).not_to be_valid
        expect(form.errors[:base]).to include("A team, department, or company goal cannot be a child of a teammate goal")
      end

      it 'allows linking when both are teammate-owned' do
        form.link_direction = 'outgoing'
        form.linking_goal = goal1
        form.child_id = goal2.id
        form.bulk_create_mode = false

        expect(form).to be_valid
      end

      it 'allows linking when parent is org-owned and child is teammate-owned' do
        form.link_direction = 'outgoing'
        form.linking_goal = org_owned_goal
        form.child_id = goal1.id
        form.bulk_create_mode = false

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
        create(:goal_link, parent: goal1, child: goal2)
        
        # Try to create goal2 -> goal1 (direct circular dependency)
        form.child_id = goal2.id
        
        # Then try to create goal2 -> goal1 through incoming direction
        form2 = GoalLinkForm.new(build(:goal_link))
        form2.link_direction = 'outgoing'
        form2.linking_goal = goal2
        form2.bulk_create_mode = false
        form2.child_id = goal1.id
        
        expect(form2).not_to be_valid
        expect(form2.errors[:base]).to include("This link would create a circular dependency")
      end
      
      it 'prevents transitive circular dependencies' do
        # Create goal1 -> goal2 -> goal3
        create(:goal_link, parent: goal1, child: goal2)
        create(:goal_link, parent: goal2, child: goal3)
        
        # Try to create goal3 -> goal1 (transitive circular dependency)
        form.child_id = goal3.id
        
        form3 = GoalLinkForm.new(build(:goal_link))
        form3.link_direction = 'outgoing'
        form3.linking_goal = goal3
        form3.bulk_create_mode = false
        form3.child_id = goal1.id
        
        expect(form3).not_to be_valid
        expect(form3.errors[:base]).to include("This link would create a circular dependency")
      end
      
      it 'allows non-circular chains' do
        # Create goal1 -> goal2
        create(:goal_link, parent: goal1, child: goal2)
        
        # Create goal2 -> goal3 (linear chain, no cycle)
        form.child_id = goal3.id
        
        form2 = GoalLinkForm.new(build(:goal_link))
        form2.link_direction = 'outgoing'
        form2.linking_goal = goal2
        form2.bulk_create_mode = false
        form2.child_id = goal3.id
        
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
        form.child_id = goal2.id
        
        expect(form.save).to be true
        expect(goal_link.parent).to eq(goal1)
        expect(goal_link.child).to eq(goal2)
      end
    end
    
    context 'with incoming direction' do
      before do
        form.link_direction = 'incoming'
        form.linking_goal = goal1
        form.bulk_create_mode = false
      end
      
      it 'creates goal link with valid attributes' do
        form.parent_id = goal2.id
        
        expect(form.save).to be true
        expect(goal_link.parent).to eq(goal2)
        expect(goal_link.child).to eq(goal1)
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
        
        expect { form.save }.to change { Goal.count }.by(2)
        expect(form.save).to be true
        
        created_goals = Goal.last(2)
        created_goals.each do |goal|
          expect(goal.goal_type).to eq('stepping_stone_activity')
          expect(goal.most_likely_target_date).to be_present
          expect(goal.owner).to be_a(CompanyTeammate)
          expect(goal.owner.id).to eq(goal1.owner.id)
          expect(goal.privacy_level).to eq(goal1.privacy_level)
          
          link = GoalLink.find_by(parent: goal1, child: goal)
          expect(link).to be_present
        end
      end
      
      it 'sets most_likely_target_date from parent goal when parent has target date' do
        parent_date = Date.current + 60.days
        goal1.update!(most_likely_target_date: parent_date)
        form.bulk_goal_titles = "New Goal 1"
        
        form.save
        
        created_goal = Goal.last
        expect(created_goal.most_likely_target_date).to eq(parent_date)
      end
      
      it 'sets most_likely_target_date to 90 days from now when parent has no target date' do
        goal1.update!(most_likely_target_date: nil)
        form.bulk_goal_titles = "New Goal 1"
        
        form.save
        
        created_goal = Goal.last
        expect(created_goal.most_likely_target_date).to eq(Date.current + 90.days)
      end
      
      it 'creates goals with specified goal_type when provided' do
        form.bulk_goal_titles = "New Goal 1\nNew Goal 2"
        form.goal_type = 'quantitative_key_result'
        
        expect { form.save }.to change { Goal.count }.by(2)
        expect(form.save).to be true
        
        created_goals = Goal.last(2)
        created_goals.each do |goal|
          expect(goal.goal_type).to eq('quantitative_key_result')
        end
      end
      
      it 'creates goals as inspirational_objective for incoming links' do
        form.link_direction = 'incoming'
        form.bulk_goal_titles = "New Goal 1"
        
        expect { form.save }.to change { Goal.count }.by(1)
        expect(form.save).to be true
        
        created_goal = Goal.last
        expect(created_goal.goal_type).to eq('inspirational_objective')
        
        link = GoalLink.find_by(parent: created_goal, child: goal1)
        expect(link).to be_present
      end
      
      it 'handles bulk service errors' do
        allow_any_instance_of(Goals::BulkCreateService).to receive(:call).and_return(false)
        allow_any_instance_of(Goals::BulkCreateService).to receive(:errors).and_return(['Error creating goal'])
        
        form.bulk_goal_titles = "New Goal 1"
        
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
        form.child_id = goal2.id
        form.metadata = { notes: 'Important link', strength: 'high' }
        
        expect(form.save).to be true
        expect(goal_link.metadata).to eq({ 'notes' => 'Important link', 'strength' => 'high' })
      end
      
      it 'allows nil metadata' do
        form.child_id = goal2.id
        form.metadata = nil
        
        expect(form.save).to be true
        expect(goal_link.metadata).to be_nil
      end
    end
    
    it 'does not save if invalid' do
      form.parent_id = nil
      form.child_id = goal2.id
      
      expect(form.save).to be false
      expect(goal_link).not_to be_persisted
    end
  end
end


