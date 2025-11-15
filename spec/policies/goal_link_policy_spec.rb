require 'rails_helper'
require 'ostruct'

RSpec.describe GoalLinkPolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:creator_person) { create(:person) }
  let(:owner_person) { create(:person) }
  let(:other_person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  
  let(:creator_teammate) { CompanyTeammate.create!(person: creator_person, organization: company) }
  let(:owner_teammate) { CompanyTeammate.create!(person: owner_person, organization: company) }
  let(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: company) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: company) }
  
  let(:goal1) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
  let(:goal2) { create(:goal, creator: creator_teammate, owner: owner_teammate) }
  let(:goal_link) { build(:goal_link, parent: goal1, child: goal2) }
  
  let(:pundit_user_creator) { OpenStruct.new(user: creator_teammate, real_user: creator_teammate) }
  let(:pundit_user_owner) { OpenStruct.new(user: owner_teammate, real_user: owner_teammate) }
  let(:pundit_user_other) { OpenStruct.new(user: other_teammate, real_user: other_teammate) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, real_user: admin_teammate) }
  
  describe 'create?' do
    it 'allows creator of parent to create link' do
      policy = GoalLinkPolicy.new(pundit_user_creator, goal_link)
      expect(policy.create?).to be true
    end
    
    it 'allows owner of parent to create link' do
      goal1.update!(owner: owner_teammate)
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
    let(:goal_link) { create(:goal_link, parent: goal1, child: goal2) }
    
    it 'allows creator of parent to destroy link' do
      policy = GoalLinkPolicy.new(pundit_user_creator, goal_link)
      expect(policy.destroy?).to be true
    end
    
    it 'allows owner of parent to destroy link' do
      goal1.update!(owner: owner_teammate)
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






