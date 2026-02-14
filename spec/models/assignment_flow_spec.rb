# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AssignmentFlow, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:company).class_name('Organization') }
    it { is_expected.to belong_to(:created_by).class_name('CompanyTeammate') }
    it { is_expected.to belong_to(:updated_by).class_name('CompanyTeammate') }
    it { is_expected.to have_many(:assignment_flow_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:assignments).through(:assignment_flow_memberships) }
  end

  describe 'validations' do
    subject { build(:assignment_flow) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:company_id) }
    it { is_expected.to validate_presence_of(:company) }
    it { is_expected.to validate_presence_of(:created_by) }
    it { is_expected.to validate_presence_of(:updated_by) }
  end

  describe '#ordered_memberships' do
    let(:organization) { create(:organization, :company) }
    let(:teammate) { create(:teammate, :unassigned_employee, organization: organization) }
    let(:flow) { create(:assignment_flow, company: organization, created_by: teammate, updated_by: teammate) }
    let(:a1) { create(:assignment, company: organization, title: 'Alpha') }
    let(:a2) { create(:assignment, company: organization, title: 'Beta') }

    it 'returns memberships ordered by placement, then group name, then assignment title' do
      create(:assignment_flow_membership, assignment_flow: flow, assignment: a2, placement: 1, added_by: teammate)
      create(:assignment_flow_membership, assignment_flow: flow, assignment: a1, placement: 1, added_by: teammate)
      ordered = flow.ordered_memberships.map(&:assignment)
      expect(ordered.map(&:title)).to eq(%w[Alpha Beta])
    end
  end
end
