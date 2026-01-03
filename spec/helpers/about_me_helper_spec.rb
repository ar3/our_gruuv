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

  describe '#goals_status_indicator' do
    context 'when no active goals exist' do
      it 'returns :red' do
        result = helper.goals_status_indicator(company_teammate)
        expect(result).to eq(:red)
      end
    end

    context 'when goals exist' do
      let!(:goal1) do
        create(:goal,
               owner: company_teammate,
               creator: company_teammate,
               company: company,
               started_at: 1.day.ago,
               completed_at: nil)
      end

      context 'when any goal completed in last 90 days' do
        before do
          goal1.update!(completed_at: 30.days.ago)
        end

        it 'returns :green' do
          result = helper.goals_status_indicator(company_teammate)
          expect(result).to eq(:green)
        end

        context 'even when other goals have no recent check-ins' do
          let!(:goal2) do
            create(:goal,
                   owner: company_teammate,
                   creator: company_teammate,
                   company: company,
                   started_at: 1.day.ago,
                   completed_at: nil)
          end

          it 'still returns :green (completed goal takes precedence)' do
            result = helper.goals_status_indicator(company_teammate)
            expect(result).to eq(:green)
          end
        end
      end

      context 'when no goals completed in last 90 days' do
        context 'when all active goals have check-ins in past 2 weeks' do
          let(:cutoff_week) { (Date.current - 14.days).beginning_of_week(:monday) }
          let(:recent_week) { cutoff_week }
          let(:confidence_reporter) { create(:person) }

          before do
            create(:goal_check_in,
                   goal: goal1,
                   check_in_week_start: recent_week,
                   confidence_reporter: confidence_reporter)
          end

          it 'returns :green' do
            result = helper.goals_status_indicator(company_teammate)
            expect(result).to eq(:green)
          end

          context 'with multiple goals' do
            let!(:goal2) do
              create(:goal,
                     owner: company_teammate,
                     creator: company_teammate,
                     company: company,
                     started_at: 1.day.ago,
                     completed_at: nil)
            end

            before do
              create(:goal_check_in,
                     goal: goal2,
                     check_in_week_start: recent_week,
                     confidence_reporter: confidence_reporter)
            end

            it 'returns :green when all goals have recent check-ins' do
              result = helper.goals_status_indicator(company_teammate)
              expect(result).to eq(:green)
            end
          end

          context 'when check-in is exactly on the cutoff week' do
            before do
              goal1.goal_check_ins.destroy_all
              create(:goal_check_in,
                     goal: goal1,
                     check_in_week_start: cutoff_week,
                     confidence_reporter: confidence_reporter)
            end

            it 'returns :green' do
              result = helper.goals_status_indicator(company_teammate)
              expect(result).to eq(:green)
            end
          end

          context 'when check-in is for current week' do
            let(:current_week) { Date.current.beginning_of_week(:monday) }

            before do
              goal1.goal_check_ins.destroy_all
              create(:goal_check_in,
                     goal: goal1,
                     check_in_week_start: current_week,
                     confidence_reporter: confidence_reporter)
            end

            it 'returns :green' do
              result = helper.goals_status_indicator(company_teammate)
              expect(result).to eq(:green)
            end
          end
        end

        context 'when some goals have recent check-ins but not all' do
          let(:cutoff_week) { (Date.current - 14.days).beginning_of_week(:monday) }
          let(:recent_week) { cutoff_week }
          let(:confidence_reporter) { create(:person) }
          let!(:goal2) do
            create(:goal,
                   owner: company_teammate,
                   creator: company_teammate,
                   company: company,
                   started_at: 1.day.ago,
                   completed_at: nil)
          end

          before do
            create(:goal_check_in,
                   goal: goal1,
                   check_in_week_start: recent_week,
                   confidence_reporter: confidence_reporter)
            # goal2 has no check-ins
          end

          it 'returns :yellow' do
            result = helper.goals_status_indicator(company_teammate)
            expect(result).to eq(:yellow)
          end
        end

        context 'when goals have check-ins but all are older than 2 weeks' do
          let(:old_week) { (Date.current - 14.days).beginning_of_week(:monday) - 1.week }
          let(:confidence_reporter) { create(:person) }

          before do
            create(:goal_check_in,
                   goal: goal1,
                   check_in_week_start: old_week,
                   confidence_reporter: confidence_reporter)
          end

          it 'returns :yellow' do
            result = helper.goals_status_indicator(company_teammate)
            expect(result).to eq(:yellow)
          end
        end

        context 'when goals have no check-ins at all' do
          it 'returns :yellow' do
            result = helper.goals_status_indicator(company_teammate)
            expect(result).to eq(:yellow)
          end
        end

        context 'week calculation edge cases' do
          let(:confidence_reporter) { create(:person) }

          context 'when check-in is exactly on the cutoff week (14 days ago)' do
            let(:cutoff_week) { (Date.current - 14.days).beginning_of_week(:monday) }

            before do
              goal1.goal_check_ins.destroy_all
              create(:goal_check_in,
                     goal: goal1,
                     check_in_week_start: cutoff_week,
                     confidence_reporter: confidence_reporter)
            end

            it 'returns :green' do
              result = helper.goals_status_indicator(company_teammate)
              expect(result).to eq(:green)
            end
          end

          context 'when check-in is one day before cutoff week' do
            let(:cutoff_week) { (Date.current - 14.days).beginning_of_week(:monday) }
            let(:old_week) { cutoff_week - 1.week }

            before do
              goal1.goal_check_ins.destroy_all
              create(:goal_check_in,
                     goal: goal1,
                     check_in_week_start: old_week,
                     confidence_reporter: confidence_reporter)
            end

            it 'returns :yellow' do
              result = helper.goals_status_indicator(company_teammate)
              expect(result).to eq(:yellow)
            end
          end
        end
      end
    end
  end
end

