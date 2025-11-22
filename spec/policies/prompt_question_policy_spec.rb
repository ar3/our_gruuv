require 'rails_helper'
require 'ostruct'

RSpec.describe PromptQuestionPolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:template) { create(:prompt_template, company: company) }
  let(:question) { create(:prompt_question, prompt_template: template) }

  let(:prompts_teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_prompts: true) }
  let(:person_teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_prompts: false) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: company) }

  let(:pundit_user_prompts) { OpenStruct.new(user: prompts_teammate, impersonating_teammate: nil) }
  let(:pundit_user_person) { OpenStruct.new(user: person_teammate, impersonating_teammate: nil) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }

  describe 'create?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = PromptQuestionPolicy.new(pundit_user_admin, question)
        expect(policy.create?).to be true
      end
    end

    context 'when user has prompts permission' do
      it 'allows access' do
        policy = PromptQuestionPolicy.new(pundit_user_prompts, question)
        expect(policy.create?).to be true
      end
    end

    context 'when user lacks prompts permission' do
      it 'denies access' do
        policy = PromptQuestionPolicy.new(pundit_user_person, question)
        expect(policy.create?).to be false
      end
    end
  end

  describe 'update?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = PromptQuestionPolicy.new(pundit_user_admin, question)
        expect(policy.update?).to be true
      end
    end

    context 'when user has prompts permission' do
      it 'allows access' do
        policy = PromptQuestionPolicy.new(pundit_user_prompts, question)
        expect(policy.update?).to be true
      end
    end

    context 'when user lacks prompts permission' do
      it 'denies access' do
        policy = PromptQuestionPolicy.new(pundit_user_person, question)
        expect(policy.update?).to be false
      end
    end
  end

  describe 'destroy?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = PromptQuestionPolicy.new(pundit_user_admin, question)
        expect(policy.destroy?).to be true
      end
    end

    context 'when user has prompts permission' do
      it 'allows access' do
        policy = PromptQuestionPolicy.new(pundit_user_prompts, question)
        expect(policy.destroy?).to be true
      end
    end

    context 'when user lacks prompts permission' do
      it 'denies access' do
        policy = PromptQuestionPolicy.new(pundit_user_person, question)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe 'cross-company access' do
    let(:other_company) { create(:organization, :company) }
    let(:other_template) { create(:prompt_template, company: other_company) }
    let(:other_question) { create(:prompt_question, prompt_template: other_template) }
    let(:other_teammate) { CompanyTeammate.create!(person: person, organization: other_company, can_manage_prompts: true) }
    let(:pundit_user_other) { OpenStruct.new(user: other_teammate, impersonating_teammate: nil) }

    context 'when question belongs to different company' do
      it 'denies create access' do
        policy = PromptQuestionPolicy.new(pundit_user_other, question)
        expect(policy.create?).to be false
      end

      it 'denies update access' do
        policy = PromptQuestionPolicy.new(pundit_user_other, question)
        expect(policy.update?).to be false
      end

      it 'denies destroy access' do
        policy = PromptQuestionPolicy.new(pundit_user_other, question)
        expect(policy.destroy?).to be false
      end
    end

    context 'when question belongs to same company' do
      it 'allows create access' do
        policy = PromptQuestionPolicy.new(pundit_user_other, other_question)
        expect(policy.create?).to be true
      end

      it 'allows update access' do
        policy = PromptQuestionPolicy.new(pundit_user_other, other_question)
        expect(policy.update?).to be true
      end

      it 'allows destroy access' do
        policy = PromptQuestionPolicy.new(pundit_user_other, other_question)
        expect(policy.destroy?).to be true
      end
    end
  end
end
