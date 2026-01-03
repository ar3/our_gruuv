require 'rails_helper'

RSpec.describe AboutMeHelper, type: :helper do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:company_teammate) { CompanyTeammate.create!(person: person, organization: company) }

  describe '#prompts_status_indicator' do
    context 'when company has no active prompts' do
      it 'returns nil' do
        result = helper.prompts_status_indicator(company_teammate)
        expect(result).to be_nil
      end
    end

    context 'when company has active prompts' do
      let!(:prompt_template) do
        create(:prompt_template, company: company, available_at: 1.day.ago)
      end

      context 'when user has no prompts' do
        it 'returns :red' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:red)
        end
      end

      context 'when user has prompts but no responses' do
        let!(:prompt) do
          create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
        end

        it 'returns :red' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:red)
        end
      end

      context 'when user has prompts with empty responses' do
        let!(:prompt) do
          create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
        end
        let!(:prompt_question) do
          create(:prompt_question, prompt_template: prompt_template, position: 1)
        end
        let!(:prompt_answer) do
          create(:prompt_answer, prompt: prompt, prompt_question: prompt_question, text: '')
        end

        it 'returns :red' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:red)
        end
      end

      context 'when user has responses but no active goals' do
        let!(:prompt) do
          create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
        end
        let!(:prompt_question) do
          create(:prompt_question, prompt_template: prompt_template, position: 1)
        end
        let!(:prompt_answer) do
          create(:prompt_answer, prompt: prompt, prompt_question: prompt_question, text: 'My answer')
        end

        it 'returns :yellow' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:yellow)
        end
      end

      context 'when user has responses and active goals associated with prompts' do
        let!(:prompt) do
          create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
        end
        let!(:prompt_question) do
          create(:prompt_question, prompt_template: prompt_template, position: 1)
        end
        let!(:prompt_answer) do
          create(:prompt_answer, prompt: prompt, prompt_question: prompt_question, text: 'My answer')
        end
        let!(:goal) do
          create(:goal,
                 owner: company_teammate,
                 creator: company_teammate,
                 company: company,
                 started_at: 1.day.ago,
                 deleted_at: nil,
                 completed_at: nil)
        end
        let!(:prompt_goal) do
          create(:prompt_goal, prompt: prompt, goal: goal)
        end

        it 'returns :green' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:green)
        end
      end

      context 'when user has responses but goals are not active' do
        let!(:prompt) do
          create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
        end
        let!(:prompt_question) do
          create(:prompt_question, prompt_template: prompt_template, position: 1)
        end
        let!(:prompt_answer) do
          create(:prompt_answer, prompt: prompt, prompt_question: prompt_question, text: 'My answer')
        end
        let!(:completed_goal) do
          create(:goal,
                 owner: company_teammate,
                 creator: company_teammate,
                 company: company,
                 started_at: 1.day.ago,
                 completed_at: 1.day.ago,
                 deleted_at: nil)
        end
        let!(:prompt_goal) do
          create(:prompt_goal, prompt: prompt, goal: completed_goal)
        end

        it 'returns :yellow' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:yellow)
        end
      end

      context 'when company is derived from root_company' do
        let(:root_company) { create(:organization, :company) }
        let(:department) { create(:organization, :department, parent: root_company) }
        let(:department_teammate) { CompanyTeammate.create!(person: person, organization: department) }
        let!(:prompt_template) do
          create(:prompt_template, company: root_company, available_at: 1.day.ago)
        end

        it 'correctly finds active prompts from root company' do
          result = helper.prompts_status_indicator(department_teammate)
          expect(result).to eq(:red) # No prompts created yet
        end
      end
    end
  end
end

