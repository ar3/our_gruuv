# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

RSpec.describe GoalAssociationPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:employee_person) { create(:person) }
  let(:manager_person) { create(:person) }
  let(:employee_teammate) do
    create(:teammate, :unassigned_employee, person: employee_person, organization: organization, can_manage_maap: false)
  end
  let(:manager_teammate) do
    create(:teammate, :unassigned_employee, person: manager_person, organization: organization, can_manage_maap: false)
  end
  let(:goal) do
    create(
      :goal,
      company_id: organization.id,
      creator: employee_teammate,
      owner: employee_teammate,
      goal_type: 'inspirational_objective',
      most_likely_target_date: nil,
      earliest_target_date: nil,
      latest_target_date: nil
    )
  end
  let(:goal_association) { GoalAssociation.new(associable: assignment, goal: goal) }

  let(:pundit_user_manager) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }
  let(:pundit_user_employee) { OpenStruct.new(user: employee_teammate, impersonating_teammate: nil) }

  describe 'create? / destroy?' do
    context 'without teammate goal flow (catalog MAAP edit)' do
      it 'delegates to assignment update? — manager without MAAP is denied' do
        policy = described_class.new(pundit_user_manager, goal_association)
        expect(policy.create?).to be false
        expect(policy.destroy?).to be false
      end

      it 'allows when viewer can update the assignment (MAAP)' do
        manager_teammate.update!(can_manage_maap: true)
        policy = described_class.new(pundit_user_manager, goal_association)
        expect(policy.create?).to be true
      end
    end

    context 'with teammate goal flow (subject teammate as goal owner context)' do
      before do
        create(:employment_tenure, company_teammate: employee_teammate, company: organization, manager: manager_teammate)
      end

      it 'allows the employee on themself' do
        goal_association.goal_flow_teammate_id = employee_teammate.id
        policy = described_class.new(pundit_user_employee, goal_association)
        expect(policy.create?).to be true
      end

      it 'allows their manager without MAAP' do
        goal_association.goal_flow_teammate_id = employee_teammate.id
        policy = described_class.new(pundit_user_manager, goal_association)
        expect(policy.create?).to be true
      end

      it 'denies an unrelated peer' do
        other = create(:teammate, :unassigned_employee, organization: organization, can_manage_maap: false)
        pundit_peer = OpenStruct.new(user: other, impersonating_teammate: nil)

        goal_association.goal_flow_teammate_id = employee_teammate.id
        policy = described_class.new(pundit_peer, goal_association)
        expect(policy.create?).to be false
      end

      it 'denies when subject teammate is not in the associable company' do
        other_org = create(:organization)
        outsider = create(:teammate, :unassigned_employee, organization: other_org, can_manage_maap: true)

        goal_association.goal_flow_teammate_id = outsider.id
        policy = described_class.new(pundit_user_manager, goal_association)
        expect(policy.create?).to be false
      end
    end
  end
end
