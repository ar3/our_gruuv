require 'rails_helper'
require 'ostruct'

RSpec.describe GoalPolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:other_company) { create(:organization, :company) }
  let(:creator_person) { create(:person) }
  let(:owner_person) { create(:person) }
  let(:other_person) { create(:person) }
  let(:manager_person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  
  let(:creator_teammate) { create(:teammate, person: creator_person, organization: company) }
  let(:owner_teammate) { create(:teammate, person: owner_person, organization: company) }
  let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
  let(:manager_teammate) { create(:teammate, person: manager_person, organization: company) }
  
  let(:personal_goal) { create(:goal, creator: creator_teammate, owner: creator_person, privacy_level: 'only_creator') }
  let(:shared_goal) { create(:goal, creator: creator_teammate, owner: owner_person, privacy_level: 'only_creator_and_owner') }
  let(:team_goal) { create(:goal, creator: creator_teammate, owner: company, privacy_level: 'everyone_in_company') }
  
  let(:pundit_user_creator) { OpenStruct.new(user: creator_person, pundit_organization: company) }
  let(:pundit_user_owner) { OpenStruct.new(user: owner_person, pundit_organization: company) }
  let(:pundit_user_other) { OpenStruct.new(user: other_person, pundit_organization: company) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin, pundit_organization: company) }
  
  describe 'index?' do
    it 'allows access to any teammate in the organization' do
      other_teammate # Ensure teammate is created
      policy = GoalPolicy.new(pundit_user_other, Goal)
      expect(policy.index?).to be true
    end
    
    it 'allows access to admins' do
      policy = GoalPolicy.new(pundit_user_admin, Goal)
      expect(policy.index?).to be true
    end
  end
  
  describe 'show?' do
    context 'with only_creator privacy level' do
      let(:goal) { personal_goal }
      
      it 'allows creator to view' do
        policy = GoalPolicy.new(pundit_user_creator, goal)
        expect(policy.show?).to be true
      end
      
      it 'allows admin to view' do
        policy = GoalPolicy.new(pundit_user_admin, goal)
        expect(policy.show?).to be true
      end
      
      it 'denies owner to view (if owner is not creator)' do
        goal.update!(owner: owner_person)
        policy = GoalPolicy.new(pundit_user_owner, goal)
        expect(policy.show?).to be false
      end
      
      it 'denies others to view' do
        policy = GoalPolicy.new(pundit_user_other, goal)
        expect(policy.show?).to be false
      end
    end
    
    context 'with only_creator_and_owner privacy level' do
      let(:goal) { shared_goal }
      
      it 'allows creator to view' do
        policy = GoalPolicy.new(pundit_user_creator, goal)
        expect(policy.show?).to be true
      end
      
      it 'allows owner to view' do
        policy = GoalPolicy.new(pundit_user_owner, goal)
        expect(policy.show?).to be true
      end
      
      it 'allows admin to view' do
        policy = GoalPolicy.new(pundit_user_admin, goal)
        expect(policy.show?).to be true
      end
      
      it 'denies others to view' do
        policy = GoalPolicy.new(pundit_user_other, goal)
        expect(policy.show?).to be false
      end
    end
    
    context 'with only_creator_owner_and_managers privacy level' do
      let(:goal) { create(:goal, creator: creator_teammate, owner: owner_person, privacy_level: 'only_creator_owner_and_managers') }
      
      before do
        # Create employment tenure with manager
        owner_employment = create(:employment_tenure, 
          teammate: owner_teammate, 
          company: company,
          manager: manager_person,
          started_at: 1.month.ago,
          ended_at: nil
        )
      end
      
      it 'allows creator to view' do
        policy = GoalPolicy.new(pundit_user_creator, goal)
        expect(policy.show?).to be true
      end
      
      it 'allows owner to view' do
        policy = GoalPolicy.new(pundit_user_owner, goal)
        expect(policy.show?).to be true
      end
      
      it 'allows manager to view' do
        policy = GoalPolicy.new(OpenStruct.new(user: manager_person, pundit_organization: company), goal)
        expect(policy.show?).to be true
      end
      
      it 'allows admin to view' do
        policy = GoalPolicy.new(pundit_user_admin, goal)
        expect(policy.show?).to be true
      end
      
      it 'denies others to view' do
        policy = GoalPolicy.new(pundit_user_other, goal)
        expect(policy.show?).to be false
      end
    end
    
    context 'with everyone_in_company privacy level' do
      let(:goal) { team_goal }
      
      it 'allows creator to view' do
        policy = GoalPolicy.new(pundit_user_creator, goal)
        expect(policy.show?).to be true
      end
      
      it 'allows teammates in company to view' do
        other_teammate # Ensure teammate is created
        policy = GoalPolicy.new(pundit_user_other, goal)
        expect(policy.show?).to be true
      end
      
      it 'allows admin to view' do
        policy = GoalPolicy.new(pundit_user_admin, goal)
        expect(policy.show?).to be true
      end
      
      it 'denies non-teammates to view' do
        outsider = create(:person)
        policy = GoalPolicy.new(OpenStruct.new(user: outsider, pundit_organization: company), goal)
        expect(policy.show?).to be false
      end
    end
  end
  
  describe 'create?' do
    it 'allows teammates to create goals' do
      creator_teammate # Ensure teammate is created
      policy = GoalPolicy.new(pundit_user_creator, Goal)
      expect(policy.create?).to be true
    end
    
    it 'allows admins to create goals' do
      policy = GoalPolicy.new(pundit_user_admin, Goal)
      expect(policy.create?).to be true
    end
  end
  
  describe 'update?' do
    context 'when user is creator' do
      it 'allows creator to update' do
        policy = GoalPolicy.new(pundit_user_creator, personal_goal)
        expect(policy.update?).to be true
      end
    end
    
    context 'when user is owner (Person)' do
      it 'allows owner to update their own goal' do
        goal = create(:goal, creator: creator_teammate, owner: owner_person, privacy_level: 'only_creator_and_owner')
        policy = GoalPolicy.new(pundit_user_owner, goal)
        expect(policy.update?).to be true
      end
    end
    
    context 'when owner is Organization' do
      let(:org_goal) { create(:goal, creator: creator_teammate, owner: company, privacy_level: 'everyone_in_company') }
      let(:org_member) { create(:person) }
      let(:org_member_teammate) { create(:teammate, person: org_member, organization: company) }
      let(:pundit_user_org_member) { OpenStruct.new(user: org_member, pundit_organization: company) }
      
      before { org_member_teammate }
      
      it 'allows creator to update' do
        policy = GoalPolicy.new(pundit_user_creator, org_goal)
        expect(policy.update?).to be true
      end
      
      it 'allows direct member of owner organization to update' do
        policy = GoalPolicy.new(pundit_user_org_member, org_goal)
        expect(policy.update?).to be true
      end
      
      it 'denies non-member to update' do
        policy = GoalPolicy.new(pundit_user_other, org_goal)
        expect(policy.update?).to be false
      end
    end
    
    context 'when user is admin' do
      it 'allows admin to update' do
        policy = GoalPolicy.new(pundit_user_admin, personal_goal)
        expect(policy.update?).to be true
      end
    end
    
    context 'when user is neither creator nor owner' do
      it 'denies update' do
        policy = GoalPolicy.new(pundit_user_other, personal_goal)
        expect(policy.update?).to be false
      end
    end
  end
  
  describe 'destroy?' do
    it 'allows creator to destroy' do
      policy = GoalPolicy.new(pundit_user_creator, personal_goal)
      expect(policy.destroy?).to be true
    end
    
    it 'allows admin to destroy' do
      policy = GoalPolicy.new(pundit_user_admin, personal_goal)
      expect(policy.destroy?).to be true
    end
    
    it 'denies owner to destroy (if not creator)' do
      policy = GoalPolicy.new(pundit_user_owner, personal_goal)
      expect(policy.destroy?).to be false
    end
    
    it 'denies others to destroy' do
      policy = GoalPolicy.new(pundit_user_other, personal_goal)
      expect(policy.destroy?).to be false
    end
  end
  
  describe 'scope' do
    let!(:personal_goal1) { create(:goal, creator: creator_teammate, owner: creator_person, privacy_level: 'only_creator_and_owner') }
    let!(:personal_goal2) { create(:goal, creator: owner_teammate, owner: owner_person, privacy_level: 'only_creator_and_owner') }
    let!(:personal_goal_private) { create(:goal, creator: creator_teammate, owner: owner_person, privacy_level: 'only_creator') }
    let!(:personal_goal_managers) { create(:goal, creator: creator_teammate, owner: owner_person, privacy_level: 'only_creator_owner_and_managers') }
    let!(:personal_goal_everyone) { create(:goal, creator: creator_teammate, owner: owner_person, privacy_level: 'everyone_in_company') }
    let!(:org_goal) { create(:goal, creator: creator_teammate, owner: company, privacy_level: 'everyone_in_company') }
    let!(:org_goal_private) { create(:goal, creator: creator_teammate, owner: company, privacy_level: 'only_creator') }
    let!(:other_company_goal) { create(:goal, creator: create(:teammate, person: other_person, organization: other_company), owner: other_company, privacy_level: 'everyone_in_company') }
    
    context 'when user is a teammate' do
      context 'when user is creator' do
        it 'returns goals where user is creator (regardless of privacy)' do
          policy = GoalPolicy::Scope.new(pundit_user_creator, Goal)
          resolved = policy.resolve
          
          expect(resolved).to include(personal_goal1) # creator is owner
          expect(resolved).to include(personal_goal_managers) # creator
          expect(resolved).to include(personal_goal_everyone) # creator
          expect(resolved).to include(org_goal) # creator
          expect(resolved).to include(org_goal_private) # creator
        end
      end
      
      context 'when user is owner (Person)' do
        it 'returns goals where user is owner and privacy allows owner visibility' do
          policy = GoalPolicy::Scope.new(pundit_user_owner, Goal)
          resolved = policy.resolve
          
          expect(resolved).to include(personal_goal2) # owner
          expect(resolved).to include(personal_goal_managers) # owner (if privacy allows)
          expect(resolved).to include(personal_goal_everyone) # owner (if privacy allows)
          expect(resolved).not_to include(personal_goal_private) # owner but privacy is only_creator
          expect(resolved).not_to include(personal_goal1) # different owner
        end
      end
      
      context 'when user is manager of owner' do
        before do
          create(:employment_tenure,
            teammate: owner_teammate,
            company: company,
            manager: manager_person,
            started_at: 1.month.ago,
            ended_at: nil
          )
        end
        
        let(:pundit_user_manager) { OpenStruct.new(user: manager_person, pundit_organization: company) }
        
        it 'returns goals where user is manager and privacy allows manager visibility' do
          policy = GoalPolicy::Scope.new(pundit_user_manager, Goal)
          resolved = policy.resolve
          
          expect(resolved).to include(personal_goal_managers) # manager of owner
          expect(resolved).not_to include(personal_goal2) # not manager, privacy is only_creator_and_owner
        end
      end
      
      context 'when user is member of organization owner' do
        let(:org_member) { create(:person) }
        let(:org_member_teammate) { create(:teammate, person: org_member, organization: company) }
        let(:pundit_user_org_member) { OpenStruct.new(user: org_member, pundit_organization: company) }
        
        before { org_member_teammate }
        
        it 'returns goals where owner is organization and privacy allows member visibility' do
          policy = GoalPolicy::Scope.new(pundit_user_org_member, Goal)
          resolved = policy.resolve
          
          expect(resolved).to include(org_goal) # member of owner org, privacy is everyone_in_company
          expect(resolved).not_to include(org_goal_private) # member but privacy is only_creator
        end
      end
      
      context 'when user is regular teammate' do
        it 'returns goals with everyone_in_company privacy' do
          policy = GoalPolicy::Scope.new(pundit_user_other, Goal)
          resolved = policy.resolve
          
          expect(resolved).to include(personal_goal_everyone) # everyone_in_company
          expect(resolved).to include(org_goal) # everyone_in_company
          expect(resolved).not_to include(personal_goal1) # only_creator_and_owner
          expect(resolved).not_to include(personal_goal_private) # only_creator
          expect(resolved).not_to include(org_goal_private) # only_creator
        end
      end
    end
    
    context 'when user is admin' do
      it 'returns all goals' do
        policy = GoalPolicy::Scope.new(pundit_user_admin, Goal)
        resolved = policy.resolve
        
        expect(resolved).to include(personal_goal1, personal_goal2, personal_goal_private, personal_goal_managers, personal_goal_everyone, org_goal, org_goal_private, other_company_goal)
      end
    end
  end
end


