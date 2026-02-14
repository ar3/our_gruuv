# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

RSpec.describe AssignmentFlowPolicy, type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:other_organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }

  let(:employed_teammate) do
    create(:teammate, :unassigned_employee, person: person, organization: organization)
  end
  let(:terminated_person) { create(:person) }
  let(:terminated_teammate) do
    create(:teammate, :terminated, person: terminated_person, organization: organization)
  end
  let(:other_org_person) { create(:person) }
  let(:other_org_teammate) do
    create(:teammate, :unassigned_employee, person: other_org_person, organization: other_organization)
  end
  let(:admin_teammate) do
    create(:teammate, :unassigned_employee, person: admin, organization: organization)
  end

  let(:assignment_flow) { create(:assignment_flow, company: organization, created_by: employed_teammate, updated_by: employed_teammate) }

  let(:pundit_user_employed) { OpenStruct.new(user: employed_teammate, impersonating_teammate: nil) }
  let(:pundit_user_terminated) { OpenStruct.new(user: terminated_teammate, impersonating_teammate: nil) }
  let(:pundit_user_other_org) { OpenStruct.new(user: other_org_teammate, impersonating_teammate: nil) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }

  describe '#show?' do
    it 'allows employed teammate in same company' do
      policy = AssignmentFlowPolicy.new(pundit_user_employed, assignment_flow)
      expect(policy.show?).to be true
    end

    it 'allows admin' do
      policy = AssignmentFlowPolicy.new(pundit_user_admin, assignment_flow)
      expect(policy.show?).to be true
    end

    it 'denies terminated teammate' do
      policy = AssignmentFlowPolicy.new(pundit_user_terminated, assignment_flow)
      expect(policy.show?).to be false
    end

    it 'denies teammate from other organization' do
      policy = AssignmentFlowPolicy.new(pundit_user_other_org, assignment_flow)
      expect(policy.show?).to be false
    end
  end

  describe '#create?' do
    it 'allows employed teammate' do
      new_flow = AssignmentFlow.new(company: organization)
      policy = AssignmentFlowPolicy.new(pundit_user_employed, new_flow)
      expect(policy.create?).to be true
    end

    it 'denies terminated teammate' do
      new_flow = AssignmentFlow.new(company: organization)
      policy = AssignmentFlowPolicy.new(pundit_user_terminated, new_flow)
      expect(policy.create?).to be false
    end
  end

  describe '#update?' do
    it 'allows employed teammate in same company' do
      policy = AssignmentFlowPolicy.new(pundit_user_employed, assignment_flow)
      expect(policy.update?).to be true
    end

    it 'denies teammate from other organization' do
      policy = AssignmentFlowPolicy.new(pundit_user_other_org, assignment_flow)
      expect(policy.update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows employed teammate in same company' do
      policy = AssignmentFlowPolicy.new(pundit_user_employed, assignment_flow)
      expect(policy.destroy?).to be true
    end
  end

  describe 'Scope' do
    it 'returns assignment flows for company when employed in same org' do
      flow1 = create(:assignment_flow, company: organization, created_by: employed_teammate, updated_by: employed_teammate)
      flow2 = create(:assignment_flow, company: other_organization, created_by: other_org_teammate, updated_by: other_org_teammate)

      scope = Pundit.policy_scope!(pundit_user_employed, AssignmentFlow)
      expect(scope).to include(flow1)
      expect(scope).not_to include(flow2)
    end
  end
end
