require 'rails_helper'

RSpec.describe PromptGoal, type: :model do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: company) }
  let(:template) { create(:prompt_template, company: company) }
  let(:prompt) { create(:prompt, company_teammate: teammate, prompt_template: template) }
  let(:goal) { create(:goal, owner: teammate, creator: teammate, company: company) }

  describe 'associations' do
    it { is_expected.to belong_to(:prompt).required }
    it { is_expected.to belong_to(:goal).required }
  end

  describe 'validations' do
    it 'validates presence of prompt' do
      prompt_goal = PromptGoal.new(goal: goal)
      expect(prompt_goal).not_to be_valid
      expect(prompt_goal.errors[:prompt]).to be_present
    end

    it 'validates presence of goal' do
      prompt_goal = PromptGoal.new(prompt: prompt)
      expect(prompt_goal).not_to be_valid
      expect(prompt_goal.errors[:goal]).to be_present
    end

    it 'validates uniqueness of goal_id scoped to prompt_id' do
      PromptGoal.create!(prompt: prompt, goal: goal)
      duplicate = PromptGoal.new(prompt: prompt, goal: goal)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:goal_id]).to be_present
    end

    it 'allows same goal for different prompts' do
      # Close the first prompt so we can create another one
      prompt.close!
      other_prompt = create(:prompt, company_teammate: teammate, prompt_template: template)
      PromptGoal.create!(prompt: prompt, goal: goal)
      other_association = PromptGoal.new(prompt: other_prompt, goal: goal)
      expect(other_association).to be_valid
    end
  end
end

