# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::PromptGoalCandidatesQuery do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: company) }
  let(:prompt) { create(:prompt, company_teammate: teammate) }

  describe '#call' do
    it 'returns goals owned by the prompt’s company_teammate, same company, not completed, not deleted' do
      g1 = create(:goal, owner: teammate, creator: teammate, company: company, title: 'G1')
      g2 = create(:goal, owner: teammate, creator: teammate, company: company, title: 'G2')
      create(:goal, owner: teammate, creator: teammate, company: company, title: 'Completed', completed_at: 1.day.ago)
      create(:goal, owner: teammate, creator: teammate, company: company, title: 'Deleted', deleted_at: 1.day.ago)

      result = described_class.new(prompt: prompt).call
      ids = result.pluck(:id)
      expect(ids).to contain_exactly(g1.id, g2.id)
    end

    it 'excludes goals owned by another teammate' do
      other = create(:company_teammate, organization: company)
      create(:goal, owner: teammate, creator: teammate, company: company, title: 'Mine')
      other_goal = create(:goal, owner: other, creator: other, company: company, title: 'Other')

      result = described_class.new(prompt: prompt).call
      expect(result.pluck(:id)).not_to include(other_goal.id)
    end

    it 'returns none when prompt has no company_teammate_id' do
      prompt_without_teammate = double('Prompt', company_teammate_id: nil, company_teammate: nil)

      result = described_class.new(prompt: prompt_without_teammate).call
      expect(result).to eq(Goal.none)
    end
  end
end
