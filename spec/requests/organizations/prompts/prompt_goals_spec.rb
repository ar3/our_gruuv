require 'rails_helper'

RSpec.describe 'Organizations::Prompts::PromptGoals', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:teammate) do
    CompanyTeammate.find_or_create_by!(person: person, organization: organization)
  end
  let(:template) { create(:prompt_template, :available, company: organization) }
  let(:prompt) { create(:prompt, company_teammate: teammate, prompt_template: template) }
  let!(:goal1) { create(:goal, owner: teammate, creator: teammate, company: organization) }
  let!(:goal2) { create(:goal, owner: teammate, creator: teammate, company: organization) }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'POST /organizations/:organization_id/prompts/:prompt_id/prompt_goals' do
    context 'with bulk_goal_titles (creating new goals)' do
      it 'creates stepping stone goals from textarea input' do
        expect {
          post organization_prompt_prompt_goals_path(organization, prompt), params: {
            bulk_goal_titles: "Goal 1\nGoal 2\nGoal 3"
          }
        }.to change { Goal.count }.by(3)
          .and change { PromptGoal.count }.by(3)
      end

      it 'creates goals with correct attributes' do
        post organization_prompt_prompt_goals_path(organization, prompt), params: {
          bulk_goal_titles: "New Stepping Stone Goal"
        }

        created_goal = Goal.last
        expect(created_goal.title).to eq('New Stepping Stone Goal')
        expect(created_goal.description).to eq('')
        expect(created_goal.goal_type).to eq('stepping_stone_activity')
        expect(created_goal.most_likely_target_date).to eq(Date.current + 90.days)
        expect(created_goal.earliest_target_date).to be_nil
        expect(created_goal.latest_target_date).to be_nil
        expect(created_goal.owner).to eq(teammate)
        expect(created_goal.creator).to eq(teammate)
        expect(created_goal.privacy_level).to eq('only_creator_and_owner')
        expect(created_goal.company_id).to eq(organization.id)
      end

      it 'associates created goals with the prompt' do
        post organization_prompt_prompt_goals_path(organization, prompt), params: {
          bulk_goal_titles: "Goal 1\nGoal 2"
        }

        created_goals = Goal.last(2)
        expect(prompt.goals).to include(*created_goals)
      end

      it 'handles empty lines and whitespace' do
        expect {
          post organization_prompt_prompt_goals_path(organization, prompt), params: {
            bulk_goal_titles: "Goal 1\n\nGoal 2\n   \nGoal 3"
          }
        }.to change { Goal.count }.by(3)
      end

      it 'strips whitespace from goal titles' do
        post organization_prompt_prompt_goals_path(organization, prompt), params: {
          bulk_goal_titles: "  Goal 1  \n  Goal 2  "
        }

        created_goals = Goal.last(2)
        expect(created_goals.map(&:title)).to eq(['Goal 1', 'Goal 2'])
      end

      it 'redirects to prompt with success notice' do
        post organization_prompt_prompt_goals_path(organization, prompt), params: {
          bulk_goal_titles: "New Goal"
        }
        expect(response).to redirect_to(edit_organization_prompt_path(organization, prompt))
        expect(flash[:notice]).to include('successfully associated')
      end

      it 'redirects to return_url when provided' do
        return_url = '/close_tab?return_text=close+tab+when+done'
        post organization_prompt_prompt_goals_path(organization, prompt), params: {
          bulk_goal_titles: "New Goal",
          return_url: return_url
        }
        expect(response).to redirect_to(return_url)
        expect(flash[:notice]).to include('successfully associated')
      end

      context 'when validation was failing' do
        it 'now succeeds after fixing owner_type assignment' do
          # This test verifies that the validation error has been fixed
          # Previously, the error was: "Owner type must be CompanyTeammate, not Teammate"
          # This occurred because Rails polymorphic associations don't preserve STI types
          post organization_prompt_prompt_goals_path(organization, prompt), params: {
            bulk_goal_titles: "Test Goal"
          }
          
          # After the fix, it should succeed and redirect to edit prompt
          expect(response).to redirect_to(edit_organization_prompt_path(organization, prompt))
          expect(flash[:notice]).to include('successfully associated')
          expect(Goal.count).to be > 0
        end
      end
    end

    context 'with existing goal_ids' do
      it 'creates prompt goal associations' do
        expect {
          post organization_prompt_prompt_goals_path(organization, prompt), params: {
            goal_ids: [goal1.id, goal2.id]
          }
        }.to change { PromptGoal.count }.by(2)
      end

      it 'redirects to prompt with success notice' do
        post organization_prompt_prompt_goals_path(organization, prompt), params: {
          goal_ids: [goal1.id]
        }
        expect(response).to redirect_to(edit_organization_prompt_path(organization, prompt))
        expect(flash[:notice]).to include('successfully associated')
      end

      it 'redirects to return_url when provided' do
        return_url = '/close_tab?return_text=close+tab+when+done'
        post organization_prompt_prompt_goals_path(organization, prompt), params: {
          goal_ids: [goal1.id],
          return_url: return_url
        }
        expect(response).to redirect_to(return_url)
        expect(flash[:notice]).to include('successfully associated')
      end
    end

    context 'with both goal_ids and bulk_goal_titles' do
      it 'creates both existing and new goal associations' do
        expect {
          post organization_prompt_prompt_goals_path(organization, prompt), params: {
            goal_ids: [goal1.id],
            bulk_goal_titles: "New Goal 1\nNew Goal 2"
          }
        }.to change { Goal.count }.by(2)
          .and change { PromptGoal.count }.by(3)
      end

      it 'redirects to return_url when provided' do
        return_url = '/close_tab?return_text=close+tab+when+done'
        post organization_prompt_prompt_goals_path(organization, prompt), params: {
          goal_ids: [goal1.id],
          bulk_goal_titles: "New Goal",
          return_url: return_url
        }
        expect(response).to redirect_to(return_url)
        expect(flash[:notice]).to include('successfully associated')
      end
    end

    context 'with empty goal_ids and empty bulk_goal_titles' do
      it 'redirects to choose_manage_goals with alert' do
        post organization_prompt_prompt_goals_path(organization, prompt), params: {
          goal_ids: [],
          bulk_goal_titles: ""
        }
        expect(response).to redirect_to(choose_manage_goals_organization_prompt_path(organization, prompt))
        expect(flash[:alert]).to include('Please select at least one existing goal or provide at least one new goal title')
      end
    end
  end

  describe 'DELETE /organizations/:organization_id/prompts/:prompt_id/prompt_goals/:id' do
    let!(:prompt_goal) { PromptGoal.create!(prompt: prompt, goal: goal1) }

    it 'destroys the prompt goal' do
      expect {
        delete organization_prompt_prompt_goal_path(organization, prompt, prompt_goal)
      }.to change { PromptGoal.count }.by(-1)
    end

    it 'redirects to prompt with success notice' do
      delete organization_prompt_prompt_goal_path(organization, prompt, prompt_goal)
      expect(response).to redirect_to(edit_organization_prompt_path(organization, prompt))
      expect(flash[:notice]).to include('successfully removed')
    end

    it 'does not delete the goal itself' do
      expect {
        delete organization_prompt_prompt_goal_path(organization, prompt, prompt_goal)
      }.not_to change { Goal.count }
    end
  end
end

