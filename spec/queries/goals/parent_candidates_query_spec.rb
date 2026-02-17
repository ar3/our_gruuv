# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::ParentCandidatesQuery do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: company) }

  describe '#call' do
    context 'when child goal is organization-owned' do
      let(:child_goal) do
        create(:goal, creator: teammate, company: company, owner: company, title: 'Child org',
               privacy_level: 'everyone_in_company')
      end

      it 'includes only company goals with everyone_in_company' do
        org_parent = create(:goal, creator: teammate, company: company, owner: company, title: 'Org parent',
                            privacy_level: 'everyone_in_company')
        teammate_goal = create(:goal, creator: teammate, owner: teammate, title: 'Teammate goal')
        child_goal

        result = described_class.new(goal: child_goal, current_teammate: teammate).call
        goal_ids = result.pluck(:id)
        expect(goal_ids).to include(org_parent.id)
        expect(goal_ids).not_to include(teammate_goal.id)
      end

      it 'excludes the child goal itself' do
        child_goal
        result = described_class.new(goal: child_goal, current_teammate: teammate).call
        expect(result.pluck(:id)).not_to include(child_goal.id)
      end
    end

    context 'when child goal is teammate-owned' do
      let(:child_goal) { create(:goal, creator: teammate, owner: teammate, title: 'Child') }

      it 'includes same-teammate goals and org/dept/team goals with everyone_in_company' do
        same_teammate = create(:goal, creator: teammate, owner: teammate, title: 'Same teammate')
        org_goal = create(:goal, creator: teammate, company: company, owner: company, title: 'Org',
                          privacy_level: 'everyone_in_company')
        child_goal

        result = described_class.new(goal: child_goal, current_teammate: teammate).call
        goal_ids = result.pluck(:id)
        expect(goal_ids).to include(same_teammate.id, org_goal.id)
      end
    end
  end
end
