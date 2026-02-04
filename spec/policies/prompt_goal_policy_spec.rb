require 'rails_helper'
require 'ostruct'

RSpec.describe PromptGoalPolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: company) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: company) }
  let(:template) { create(:prompt_template, company: company) }
  let(:prompt) { create(:prompt, company_teammate: teammate, prompt_template: template) }
  let(:goal) { create(:goal, owner: teammate, creator: teammate, company: company) }
  let(:prompt_goal) { PromptGoal.new(prompt: prompt, goal: goal) }

  let(:pundit_user) { OpenStruct.new(user: teammate, impersonating_teammate: nil) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }

  describe 'create?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = PromptGoalPolicy.new(pundit_user_admin, prompt_goal)
        expect(policy.create?).to be true
      end
    end

    context 'when user owns the prompt' do
      it 'allows access' do
        policy = PromptGoalPolicy.new(pundit_user, prompt_goal)
        expect(policy.create?).to be true
      end
    end

    context 'when user can update the prompt' do
      let(:manager_person) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.find_or_create_by!(person: manager_person, organization: company) }
      let(:pundit_user_manager) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }

      before do
        create(:employment_tenure,
          teammate: teammate,
          company: company,
          manager: manager_person,
          started_at: 1.month.ago
        )
      end

      it 'allows access' do
        policy = PromptGoalPolicy.new(pundit_user_manager, prompt_goal)
        expect(policy.create?).to be true
      end
    end

    context 'when user cannot update the prompt' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { CompanyTeammate.find_or_create_by!(person: other_person, organization: company) }
      let(:pundit_user_other) { OpenStruct.new(user: other_teammate, impersonating_teammate: nil) }

      it 'denies access' do
        policy = PromptGoalPolicy.new(pundit_user_other, prompt_goal)
        expect(policy.create?).to be false
      end
    end
  end

  describe 'destroy?' do
    it 'uses same authorization as create' do
      policy = PromptGoalPolicy.new(pundit_user, prompt_goal)
      expect(policy.destroy?).to eq(policy.create?)
    end
  end
end


