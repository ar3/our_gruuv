# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AssignmentFlowMembership, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:assignment_flow) }
    it { is_expected.to belong_to(:assignment) }
    it { is_expected.to belong_to(:added_by).class_name('CompanyTeammate') }
  end

  describe 'validations' do
    subject { create(:assignment_flow_membership) }
    it { is_expected.to validate_presence_of(:placement) }
    it { is_expected.to validate_numericality_of(:placement).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_uniqueness_of(:assignment_id).scoped_to(:assignment_flow_id) }
  end

  describe 'assignment_belongs_to_flow_company' do
    let(:org1) { create(:organization, :company) }
    let(:org2) { create(:organization, :company) }
    let(:teammate) { create(:teammate, :unassigned_employee, organization: org1) }
    let(:flow) { create(:assignment_flow, company: org1, created_by: teammate, updated_by: teammate) }
    let(:assignment_other_company) { create(:assignment, company: org2) }

    it 'invalid when assignment belongs to different company' do
      membership = build(:assignment_flow_membership, assignment_flow: flow, assignment: assignment_other_company, added_by: teammate)
      expect(membership).not_to be_valid
      expect(membership.errors[:assignment]).to include('must belong to the same company as the assignment flow')
    end

    it 'valid when assignment belongs to same company' do
      assignment_same = create(:assignment, company: org1)
      membership = build(:assignment_flow_membership, assignment_flow: flow, assignment: assignment_same, placement: 0, added_by: teammate)
      expect(membership).to be_valid
    end
  end
end
