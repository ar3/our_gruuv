require 'rails_helper'

RSpec.describe AssignmentOutcomePolicy, type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:assignment_outcome) { create(:assignment_outcome, assignment: assignment) }
  
  let(:admin) { create(:person, :admin) }
  let(:maap_person) { create(:person) }
  let(:regular_person) { create(:person) }
  
  let(:admin_teammate) { create(:teammate, person: admin, organization: organization) }
  let(:maap_teammate) { create(:teammate, person: maap_person, organization: organization, can_manage_maap: true) }
  let(:regular_teammate) { create(:teammate, person: regular_person, organization: organization) }
  
  subject { described_class }

  permissions :show? do
    it 'allows admin to view' do
      expect(subject).to permit(admin_teammate, assignment_outcome)
    end

    it 'allows teammate in same organization to view' do
      expect(subject).to permit(regular_teammate, assignment_outcome)
    end

    it 'denies teammate in different organization' do
      other_org = create(:organization, :company)
      other_teammate = create(:teammate, person: regular_person, organization: other_org)
      expect(subject).not_to permit(other_teammate, assignment_outcome)
    end
  end


  permissions :edit?, :update? do
    it 'allows admin to edit' do
      expect(subject).to permit(admin_teammate, assignment_outcome)
    end

    it 'allows teammate with MAAP permission to edit' do
      expect(subject).to permit(maap_teammate, assignment_outcome)
    end

    it 'denies regular teammate without MAAP permission' do
      expect(subject).not_to permit(regular_teammate, assignment_outcome)
    end

    it 'denies teammate in different organization' do
      other_org = create(:organization, :company)
      other_teammate = create(:teammate, person: maap_person, organization: other_org, can_manage_maap: true)
      expect(subject).not_to permit(other_teammate, assignment_outcome)
    end
  end
end
