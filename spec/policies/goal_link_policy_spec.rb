require 'rails_helper'
require 'ostruct'

RSpec.describe GoalLinkPolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:creator_person) { create(:person) }
  let(:owner_person) { create(:person) }
  let(:other_person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  
  let(:creator_teammate) { create(:teammate, person: creator_person, organization: company) }
  let(:owner_teammate) { create(:teammate, person: owner_person, organization: company) }
  let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
  
  let(:goal1) { create(:goal, creator: creator_teammate, owner: creator_person) }
  let(:goal2) { create(:goal, creator: creator_teammate, owner: owner_person) }
  let(:goal_link) { build(:goal_link, this_goal: goal1, that_goal: goal2) }
  
  let(:pundit_user_creator) { OpenStruct.new(user: creator_person, pundit_organization: company) }
  let(:pundit_user_owner) { OpenStruct.new(user: owner_person, pundit_organization: company) }
  let(:pundit_user_other) { OpenStruct.new(user: other_person, pundit_organization: company) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin, pundit_organization: company) }
  
  describe 'create?' do
    it 'allows creator of this_goal to create link' do
      policy = GoalLinkPolicy.new(pundit_user_creator, goal_link)
      expect(policy.create?).to be true
    end
    
    it 'allows owner of this_goal to create link' do
      goal1.update!(owner: owner_person)
      policy = GoalLinkPolicy.new(pundit_user_owner, goal_link)
      expect(policy.create?).to be true
    end
    
    it 'allows admin to create link' do
      policy = GoalLinkPolicy.new(pundit_user_admin, goal_link)
      expect(policy.create?).to be true
    end
    
    it 'denies others to create link' do
      policy = GoalLinkPolicy.new(pundit_user_other, goal_link)
      expect(policy.create?).to be false
    end
  end
  
  describe 'destroy?' do
    let(:goal_link) { create(:goal_link, this_goal: goal1, that_goal: goal2) }
    
    it 'allows creator of this_goal to destroy link' do
      policy = GoalLinkPolicy.new(pundit_user_creator, goal_link)
      expect(policy.destroy?).to be true
    end
    
    it 'allows owner of this_goal to destroy link' do
      goal1.update!(owner: owner_person)
      policy = GoalLinkPolicy.new(pundit_user_owner, goal_link)
      expect(policy.destroy?).to be true
    end
    
    it 'allows admin to destroy link' do
      policy = GoalLinkPolicy.new(pundit_user_admin, goal_link)
      expect(policy.destroy?).to be true
    end
    
    it 'denies others to destroy link' do
      policy = GoalLinkPolicy.new(pundit_user_other, goal_link)
      expect(policy.destroy?).to be false
    end
  end
end

