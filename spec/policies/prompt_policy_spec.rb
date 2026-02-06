require 'rails_helper'
require 'ostruct'

RSpec.describe PromptPolicy, type: :policy do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: company) }
  let(:prompt_teammate) { CompanyTeammate.create!(person: create(:person), organization: company) }
  let(:prompt) { create(:prompt, company_teammate: prompt_teammate) }

  let(:prompts_teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_prompts: true) }
  let(:person_teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_prompts: false) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: company) }

  let(:pundit_user_prompts) { OpenStruct.new(user: prompts_teammate, impersonating_teammate: nil) }
  let(:pundit_user_person) { OpenStruct.new(user: person_teammate, impersonating_teammate: nil) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }
  let(:pundit_user_owner) { OpenStruct.new(user: prompt_teammate, impersonating_teammate: nil) }

  describe 'show?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = PromptPolicy.new(pundit_user_admin, prompt)
        expect(policy.show?).to be true
      end
    end

    context 'when user owns the prompt' do
      it 'allows access' do
        policy = PromptPolicy.new(pundit_user_owner, prompt)
        expect(policy.show?).to be true
      end
    end

    context 'when user has prompts permission' do
      it 'allows access' do
        policy = PromptPolicy.new(pundit_user_prompts, prompt)
        expect(policy.show?).to be true
      end
    end

    context 'when user is in managerial hierarchy' do
      let(:manager_person) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.find_or_create_by!(person: manager_person, organization: company) }
      let(:pundit_user_manager) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }
      
      before do
        # Create employment tenure where manager_person manages prompt_teammate.person
        employment_tenure = create(:employment_tenure,
          teammate: prompt_teammate,
          company: company,
          manager: manager_person,
          started_at: 1.month.ago
        )
      end

      it 'allows access' do
        policy = PromptPolicy.new(pundit_user_manager, prompt)
        expect(policy.show?).to be true
      end
    end

    context 'when user lacks access' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { CompanyTeammate.find_or_create_by!(person: other_person, organization: company) }
      let(:pundit_user_other) { OpenStruct.new(user: other_teammate, impersonating_teammate: nil) }

      it 'denies access' do
        policy = PromptPolicy.new(pundit_user_other, prompt)
        expect(policy.show?).to be false
      end
    end
  end

  describe 'create?' do
    context 'when user is admin' do
      it 'allows access' do
        policy = PromptPolicy.new(pundit_user_admin, Prompt)
        expect(policy.create?).to be true
      end
    end

    context 'when user is teammate' do
      it 'allows access' do
        policy = PromptPolicy.new(pundit_user_person, Prompt)
        expect(policy.create?).to be true
      end
    end
  end

  describe 'update?' do
    context 'when prompt is open' do
      let(:open_prompt) { create(:prompt, :open, company_teammate: prompt_teammate) }

      context 'when user is admin but not the prompt owner' do
        it 'denies access (only owner can update)' do
          policy = PromptPolicy.new(pundit_user_admin, open_prompt)
          expect(policy.update?).to be false
        end
      end

      context 'when user owns the prompt' do
        it 'allows access' do
          policy = PromptPolicy.new(pundit_user_owner, open_prompt)
          expect(policy.update?).to be true
        end
      end

      context 'when user has can_manage_prompts but is not the owner' do
        it 'denies access (only owner can update)' do
          policy = PromptPolicy.new(pundit_user_prompts, open_prompt)
          expect(policy.update?).to be false
        end
      end

      context 'when user is manager of prompt owner but not the owner' do
        let(:manager_person) { create(:person) }
        let(:manager_teammate) { CompanyTeammate.find_or_create_by!(person: manager_person, organization: company) }
        let(:pundit_user_manager) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }

        before do
          create(:employment_tenure,
            teammate: prompt_teammate,
            company: company,
            manager: manager_person,
            started_at: 1.month.ago
          )
        end

        it 'denies access (only owner can update)' do
          policy = PromptPolicy.new(pundit_user_manager, open_prompt)
          expect(policy.update?).to be false
        end
      end
    end

    context 'when prompt is closed' do
      let(:closed_prompt) { create(:prompt, :closed, company_teammate: prompt_teammate) }

      it 'denies access even for owner' do
        policy = PromptPolicy.new(pundit_user_owner, closed_prompt)
        expect(policy.update?).to be false
      end
    end
  end

  describe 'close?' do
    let(:open_prompt) { create(:prompt, :open, company_teammate: prompt_teammate) }

    context 'when user is owner' do
      it 'allows closing' do
        policy = PromptPolicy.new(pundit_user_owner, open_prompt)
        expect(policy.close?).to be true
      end
    end

    context 'when user is manager but not owner' do
      let(:manager_person) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.find_or_create_by!(person: manager_person, organization: company) }
      let(:pundit_user_manager) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }

      before do
        create(:employment_tenure,
          teammate: prompt_teammate,
          company: company,
          manager: manager_person,
          started_at: 1.month.ago
        )
      end

      it 'denies closing' do
        policy = PromptPolicy.new(pundit_user_manager, open_prompt)
        expect(policy.close?).to be false
      end
    end

    context 'when prompt is closed' do
      let(:closed_prompt) { create(:prompt, :closed, company_teammate: prompt_teammate) }

      it 'denies closing even for owner' do
        policy = PromptPolicy.new(pundit_user_owner, closed_prompt)
        expect(policy.close?).to be false
      end
    end
  end

  describe 'Scope' do
    let(:other_company) { create(:organization, :company) }
    let(:other_person) { create(:person) }
    let(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: other_company) }
    let!(:other_prompt) { create(:prompt, company_teammate: other_teammate) }

    describe 'when user is admin' do
      it 'returns all prompts' do
        scope = PromptPolicy::Scope.new(pundit_user_admin, Prompt)
        results = scope.resolve
        expect(results).to include(prompt, other_prompt)
      end
    end

    describe 'when user has can_manage_prompts permission' do
      it 'returns all prompts in the company' do
        scope = PromptPolicy::Scope.new(pundit_user_prompts, Prompt)
        results = scope.resolve
        expect(results).to include(prompt)
        # Should not include prompts from other companies
        expect(results).not_to include(other_prompt)
      end
    end

    describe 'when user owns prompts' do
      it 'returns prompts owned by the user' do
        scope = PromptPolicy::Scope.new(pundit_user_owner, Prompt)
        results = scope.resolve
        expect(results).to include(prompt)
        expect(results).not_to include(other_prompt)
      end
    end

    describe 'when user is in managerial hierarchy' do
      let(:manager_person) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.find_or_create_by!(person: manager_person, organization: company) }
      let(:pundit_user_manager) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }
      let!(:employee_prompt) { create(:prompt, company_teammate: prompt_teammate) }

      before do
        # Create employment tenure where manager_person manages prompt_teammate.person
        # This makes prompt_teammate.person a direct report of manager_person
        create(:employment_tenure,
          teammate: prompt_teammate,
          company: company,
          manager: manager_person,
          started_at: 1.month.ago,
          ended_at: nil
        )
      end

      it 'returns prompts owned by people the user manages' do
        scope = PromptPolicy::Scope.new(pundit_user_manager, Prompt)
        results = scope.resolve
        # The scope should include prompts from people the manager manages
        # Since manager_person manages prompt_teammate.person, employee_prompt should be included
        expect(results).to include(employee_prompt)
      end

      context 'with indirect reports' do
        let(:indirect_report_person) { create(:person) }
        let(:indirect_report_teammate) { CompanyTeammate.find_or_create_by!(person: indirect_report_person, organization: company) }
        let!(:indirect_report_prompt) { create(:prompt, company_teammate: indirect_report_teammate) }

        before do
          # Create employment tenure where prompt_teammate.person manages indirect_report_person
          # This makes indirect_report_person an indirect report of manager_person
          create(:employment_tenure,
            teammate: indirect_report_teammate,
            company: company,
            manager: prompt_teammate.person,
            started_at: 1.month.ago,
            ended_at: nil
          )
        end

        it 'returns prompts owned by indirect reports' do
          scope = PromptPolicy::Scope.new(pundit_user_manager, Prompt)
          results = scope.resolve
          # Should include both direct and indirect reports
          expect(results).to include(employee_prompt, indirect_report_prompt)
        end
      end
    end

    describe 'when user has no access' do
      let(:no_access_person) { create(:person) }
      let(:no_access_teammate) { CompanyTeammate.find_or_create_by!(person: no_access_person, organization: company) }
      let(:pundit_user_no_access) { OpenStruct.new(user: no_access_teammate, impersonating_teammate: nil) }

      it 'returns only prompts owned by the user' do
        user_prompt = create(:prompt, company_teammate: no_access_teammate)
        scope = PromptPolicy::Scope.new(pundit_user_no_access, Prompt)
        results = scope.resolve
        expect(results).to include(user_prompt)
        expect(results).not_to include(prompt)
      end
    end

    describe 'when user is not a teammate' do
      let(:non_teammate_person) { create(:person) }
      let(:pundit_user_non_teammate) { OpenStruct.new(user: nil, impersonating_teammate: nil) }

      it 'returns empty scope' do
        scope = PromptPolicy::Scope.new(pundit_user_non_teammate, Prompt)
        results = scope.resolve
        expect(results).to be_empty
      end
    end
  end
end

