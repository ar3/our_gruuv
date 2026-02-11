require 'rails_helper'
require 'ostruct'

RSpec.describe GoalCheckInPolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:creator_person) { create(:person) }
  let(:owner_person) { create(:person) }
  let(:other_person) { create(:person) }
  let(:admin) { create(:person, :admin) }

  let(:creator_teammate) { CompanyTeammate.create!(person: creator_person, organization: company) }
  let(:owner_teammate) { CompanyTeammate.create!(person: owner_person, organization: company) }
  let(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: company) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: company) }

  let(:pundit_user_creator) { OpenStruct.new(user: creator_teammate, impersonating_teammate: nil) }
  let(:pundit_user_owner) { OpenStruct.new(user: owner_teammate, impersonating_teammate: nil) }
  let(:pundit_user_other) { OpenStruct.new(user: other_teammate, impersonating_teammate: nil) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }

  describe 'create? and update?' do
    context 'when goal is teammate-owned' do
      let(:goal) { create(:goal, creator: creator_teammate, owner: owner_teammate, company: company, privacy_level: 'everyone_in_company') }
      let(:goal_check_in) { GoalCheckIn.new(goal: goal) }

      it 'allows creator to add check-in' do
        policy = GoalCheckInPolicy.new(pundit_user_creator, goal_check_in)
        expect(policy.create?).to be true
        expect(policy.update?).to be true
      end

      it 'allows owner to add check-in' do
        policy = GoalCheckInPolicy.new(pundit_user_owner, goal_check_in)
        expect(policy.create?).to be true
        expect(policy.update?).to be true
      end

      it 'denies other teammate who can view but is not creator or owner' do
        policy = GoalCheckInPolicy.new(pundit_user_other, goal_check_in)
        expect(policy.create?).to be false
        expect(policy.update?).to be false
      end

      it 'allows admin to add check-in' do
        policy = GoalCheckInPolicy.new(pundit_user_admin, goal_check_in)
        expect(policy.create?).to be true
        expect(policy.update?).to be true
      end
    end

    context 'when goal is organization-owned' do
      let(:goal) { create(:goal, creator: creator_teammate, owner: company, company: company, privacy_level: 'everyone_in_company') }
      let(:goal_check_in) { GoalCheckIn.new(goal: goal) }

      it 'allows any teammate who can view the goal to add check-in' do
        policy = GoalCheckInPolicy.new(pundit_user_other, goal_check_in)
        expect(policy.create?).to be true
        expect(policy.update?).to be true
      end
    end
  end
end
