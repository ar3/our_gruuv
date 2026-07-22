# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::ParentCandidatesQuery do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: company) }
  let(:other_teammate) { create(:company_teammate, organization: company) }
  let(:department) { create(:department, company: company) }
  let(:team) { create(:team, company: company, department: department) }

  describe '#call' do
    context 'when child goal is organization-owned' do
      let(:child_goal) do
        create(:goal, creator: teammate, company: company, owner: company, title: 'Child org',
               privacy_level: 'everyone_in_company')
      end

      it 'includes only company goals with everyone_in_company' do
        org_parent = create(:goal, creator: teammate, company: company, owner: company, title: 'Org parent',
                            privacy_level: 'everyone_in_company')
        dept_goal = create(:goal, creator: teammate, company: company, owner: department, title: 'Dept goal',
                           privacy_level: 'everyone_in_company')
        teammate_goal = create(:goal, creator: teammate, owner: teammate, title: 'Teammate goal')
        child_goal

        result = described_class.new(goal: child_goal, current_teammate: teammate).call
        goal_ids = result.pluck(:id)
        expect(goal_ids).to include(org_parent.id)
        expect(goal_ids).not_to include(dept_goal.id, teammate_goal.id)
      end

      it 'excludes the child goal itself' do
        child_goal
        result = described_class.new(goal: child_goal, current_teammate: teammate).call
        expect(result.pluck(:id)).not_to include(child_goal.id)
      end
    end

    context 'when child goal is department-owned' do
      let(:child_goal) do
        create(:goal, creator: teammate, company: company, owner: department, title: 'Child dept',
               privacy_level: 'everyone_in_company')
      end

      it 'includes company, department, and team goals with everyone_in_company' do
        org_goal = create(:goal, creator: teammate, company: company, owner: company, title: 'Org',
                          privacy_level: 'everyone_in_company')
        dept_goal = create(:goal, creator: other_teammate, company: company, owner: department, title: 'Dept',
                           privacy_level: 'everyone_in_company')
        team_goal = create(:goal, creator: other_teammate, company: company, owner: team, title: 'Team',
                           privacy_level: 'everyone_in_company')
        teammate_goal = create(:goal, creator: teammate, owner: teammate, title: 'Teammate')
        private_dept = create(:goal, creator: teammate, company: company, owner: department, title: 'Private dept',
                              privacy_level: 'only_creator_owner_and_managers')
        child_goal

        result = described_class.new(goal: child_goal, current_teammate: teammate).call
        goal_ids = result.pluck(:id)
        expect(goal_ids).to include(org_goal.id, dept_goal.id, team_goal.id)
        expect(goal_ids).not_to include(teammate_goal.id, private_dept.id)
      end
    end

    context 'when child goal is team-owned' do
      let(:child_goal) do
        create(:goal, creator: teammate, company: company, owner: team, title: 'Child team',
               privacy_level: 'everyone_in_company')
      end

      it 'includes company, department, and team goals with everyone_in_company' do
        org_goal = create(:goal, creator: teammate, company: company, owner: company, title: 'Org',
                          privacy_level: 'everyone_in_company')
        dept_goal = create(:goal, creator: other_teammate, company: company, owner: department, title: 'Dept',
                           privacy_level: 'everyone_in_company')
        team_goal = create(:goal, creator: other_teammate, company: company, owner: team, title: 'Team',
                           privacy_level: 'everyone_in_company')
        teammate_goal = create(:goal, creator: teammate, owner: teammate, title: 'Teammate')
        child_goal

        result = described_class.new(goal: child_goal, current_teammate: teammate).call
        goal_ids = result.pluck(:id)
        expect(goal_ids).to include(org_goal.id, dept_goal.id, team_goal.id)
        expect(goal_ids).not_to include(teammate_goal.id)
      end
    end

    context 'when child goal is teammate-owned' do
      let(:child_goal) { create(:goal, creator: other_teammate, owner: other_teammate, title: 'Child') }

      it 'includes same-owner goals created by the viewer or everyone_in_company, plus company-visible org/dept/team' do
        created_by_viewer = create(:goal, creator: teammate, owner: other_teammate, title: 'Created by viewer',
                                   privacy_level: 'only_creator_and_owner')
        public_same_owner = create(:goal, creator: other_teammate, owner: other_teammate, title: 'Public same owner',
                                   privacy_level: 'everyone_in_company')
        private_other = create(:goal, creator: other_teammate, owner: other_teammate, title: 'Private other',
                               privacy_level: 'only_creator')
        viewer_own_goal = create(:goal, creator: teammate, owner: teammate, title: 'Viewer own')
        org_goal = create(:goal, creator: teammate, company: company, owner: company, title: 'Org',
                          privacy_level: 'everyone_in_company')
        dept_goal = create(:goal, creator: other_teammate, company: company, owner: department, title: 'Dept',
                           privacy_level: 'everyone_in_company')
        child_goal

        result = described_class.new(goal: child_goal, current_teammate: teammate).call
        goal_ids = result.pluck(:id)
        expect(goal_ids).to include(created_by_viewer.id, public_same_owner.id, org_goal.id, dept_goal.id)
        expect(goal_ids).not_to include(private_other.id, viewer_own_goal.id)
      end

      it 'includes the owner viewer\'s own private goals they created when they own the child' do
        own_child = create(:goal, creator: teammate, owner: teammate, title: 'Own child')
        own_private = create(:goal, creator: teammate, owner: teammate, title: 'Own private',
                             privacy_level: 'only_creator')
        own_child

        result = described_class.new(goal: own_child, current_teammate: teammate).call
        expect(result.pluck(:id)).to include(own_private.id)
      end
    end

    it 'excludes completed and deleted goals' do
      child_goal = create(:goal, creator: teammate, company: company, owner: company, title: 'Child',
                          privacy_level: 'everyone_in_company')
      completed = create(:goal, creator: teammate, company: company, owner: company, title: 'Done',
                         privacy_level: 'everyone_in_company', started_at: 1.week.ago, completed_at: 1.day.ago)
      deleted = create(:goal, creator: teammate, company: company, owner: company, title: 'Deleted',
                       privacy_level: 'everyone_in_company', deleted_at: Time.current)

      result = described_class.new(goal: child_goal, current_teammate: teammate).call
      expect(result.pluck(:id)).not_to include(completed.id, deleted.id)
    end
  end
end
