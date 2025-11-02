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
    let!(:personal_goal1) { create(:goal, creator: creator_teammate, owner: creator_person) }
    let!(:personal_goal2) { create(:goal, creator: owner_teammate, owner: owner_person) }
    let!(:team_goal1) { create(:goal, creator: creator_teammate, owner: company) }
    let!(:other_company_goal) { create(:goal, creator: create(:teammate, person: other_person, organization: other_company), owner: other_company) }
    let!(:other_person_private_goal) { create(:goal, creator: owner_teammate, owner: owner_person, privacy_level: 'only_creator') }
    
    context 'when user is a teammate' do
      it 'returns goals where user is owner, creator, or teammate of owner organization' do
        policy = GoalPolicy::Scope.new(pundit_user_creator, Goal)
        resolved = policy.resolve
        
        expect(resolved).to include(personal_goal1) # creator is owner
        expect(resolved).to include(team_goal1) # creator and teammate of owner org
        expect(resolved).not_to include(personal_goal2) # different person
        expect(resolved).not_to include(other_company_goal) # different company
        expect(resolved).not_to include(other_person_private_goal) # private goal of another person
      end
    end
    
    context 'when user is admin' do
      it 'returns all goals' do
        policy = GoalPolicy::Scope.new(pundit_user_admin, Goal)
        resolved = policy.resolve
        
        expect(resolved).to include(personal_goal1, personal_goal2, team_goal1, other_company_goal, other_person_private_goal)
      end
    end
  end
end


