require 'rails_helper'
require 'ostruct'

RSpec.describe PromptTemplatePolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:template) { create(:prompt_template, company: company) }

  let(:prompts_teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_prompts: true) }
  let(:person_teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_prompts: false) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: company) }

  let(:pundit_user_prompts) { OpenStruct.new(user: prompts_teammate, impersonating_teammate: nil) }
  let(:pundit_user_person) { OpenStruct.new(user: person_teammate, impersonating_teammate: nil) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }


  describe 'create?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = PromptTemplatePolicy.new(pundit_user_admin, PromptTemplate)
        expect(policy.create?).to be true
      end
    end

    context 'when user has prompts permission' do
      it 'allows access' do
        policy = PromptTemplatePolicy.new(pundit_user_prompts, PromptTemplate)
        expect(policy.create?).to be true
      end
    end

    context 'when user lacks prompts permission' do
      it 'denies access' do
        policy = PromptTemplatePolicy.new(pundit_user_person, PromptTemplate)
        expect(policy.create?).to be false
      end
    end
  end

  describe 'update?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = PromptTemplatePolicy.new(pundit_user_admin, template)
        expect(policy.update?).to be true
      end
    end

    context 'when user has prompts permission for template company' do
      it 'allows access' do
        policy = PromptTemplatePolicy.new(pundit_user_prompts, template)
        expect(policy.update?).to be true
      end
    end

    context 'when user lacks prompts permission' do
      it 'denies access' do
        policy = PromptTemplatePolicy.new(pundit_user_person, template)
        expect(policy.update?).to be false
      end
    end
  end

  describe 'destroy?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = PromptTemplatePolicy.new(pundit_user_admin, template)
        expect(policy.destroy?).to be true
      end
    end

    context 'when user has prompts permission' do
      it 'allows access' do
        policy = PromptTemplatePolicy.new(pundit_user_prompts, template)
        expect(policy.destroy?).to be true
      end
    end

    context 'when user lacks prompts permission' do
      it 'denies access' do
        policy = PromptTemplatePolicy.new(pundit_user_person, template)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe 'show?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = PromptTemplatePolicy.new(pundit_user_admin, template)
        expect(policy.show?).to be true
      end
    end

    context 'when user has prompts permission for template company' do
      it 'allows access' do
        policy = PromptTemplatePolicy.new(pundit_user_prompts, template)
        expect(policy.show?).to be true
      end
    end

    context 'when user lacks prompts permission' do
      it 'denies access' do
        policy = PromptTemplatePolicy.new(pundit_user_person, template)
        expect(policy.show?).to be false
      end
    end

    context 'when template belongs to different company' do
      let(:other_company) { create(:organization, :company) }
      let(:other_template) { create(:prompt_template, company: other_company) }
      let(:other_teammate) { CompanyTeammate.create!(person: person, organization: other_company, can_manage_prompts: true) }
      let(:pundit_user_other) { OpenStruct.new(user: other_teammate, impersonating_teammate: nil) }

      it 'denies access to template from different company' do
        policy = PromptTemplatePolicy.new(pundit_user_other, template)
        expect(policy.show?).to be false
      end

      it 'allows access to template from same company' do
        policy = PromptTemplatePolicy.new(pundit_user_other, other_template)
        expect(policy.show?).to be true
      end
    end
  end

  describe 'scope' do
    let(:other_company) { create(:organization, :company) }
    let!(:template1) { create(:prompt_template, company: company) }
    let!(:template2) { create(:prompt_template, company: company) }
    let!(:other_company_template) { create(:prompt_template, company: other_company) }

    context 'when user has prompts permission for organization' do
      it 'returns templates for that organization' do
        policy = PromptTemplatePolicy::Scope.new(pundit_user_prompts, PromptTemplate)
        resolved = policy.resolve
        expect(resolved).to include(template1, template2)
        expect(resolved).not_to include(other_company_template)
      end
    end

    context 'when user lacks prompts permission' do
      it 'returns empty scope' do
        policy = PromptTemplatePolicy::Scope.new(pundit_user_person, PromptTemplate)
        expect(policy.resolve).to be_empty
      end
    end

    context 'when user is admin' do
      it 'returns all templates' do
        policy = PromptTemplatePolicy::Scope.new(pundit_user_admin, PromptTemplate)
        resolved = policy.resolve
        expect(resolved).to include(template1, template2, other_company_template)
      end
    end

    context 'when organization has root_company' do
      # Organizations are their own root (no parent hierarchy); teammate in company sees that company's templates
      let(:company_teammate) { create(:teammate, person: person, organization: company, can_manage_prompts: true) }
      let(:pundit_user_team) { OpenStruct.new(user: company_teammate, impersonating_teammate: nil) }

      it 'returns templates from root company' do
        policy = PromptTemplatePolicy::Scope.new(pundit_user_team, PromptTemplate)
        resolved = policy.resolve
        expect(resolved).to include(template1, template2)
        expect(resolved).not_to include(other_company_template)
      end
    end
  end
end
