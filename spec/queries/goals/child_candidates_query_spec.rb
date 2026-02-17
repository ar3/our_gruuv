# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::ChildCandidatesQuery do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: company) }

  describe '#call' do
    context 'when parent goal is teammate-owned' do
      let(:parent_goal) { create(:goal, creator: teammate, owner: teammate, title: 'Parent') }

      it 'includes only goals owned by the same teammate' do
        same_teammate = create(:goal, creator: teammate, owner: teammate, title: 'Same teammate')
        org_goal = create(:goal, creator: teammate, company: company, owner: company, title: 'Org',
                          privacy_level: 'everyone_in_company')
        parent_goal

        result = described_class.new(goal: parent_goal, current_teammate: teammate).call
        goal_ids = result.pluck(:id)
        expect(goal_ids).to include(same_teammate.id)
        expect(goal_ids).not_to include(org_goal.id)
      end

      it 'excludes the parent goal itself' do
        parent_goal
        result = described_class.new(goal: parent_goal, current_teammate: teammate).call
        expect(result.pluck(:id)).not_to include(parent_goal.id)
      end
    end

    context 'when parent goal is organization-owned' do
      let(:parent_goal) do
        create(:goal, creator: teammate, company: company, owner: company, title: 'Parent',
               privacy_level: 'everyone_in_company')
      end

      it 'includes goals with everyone_in_company' do
        child_goal = create(:goal, creator: teammate, company: company, owner: company, title: 'Child',
                            privacy_level: 'everyone_in_company')
        parent_goal

        result = described_class.new(goal: parent_goal, current_teammate: teammate).call
        expect(result.pluck(:id)).to include(child_goal.id)
      end
    end
  end
end
