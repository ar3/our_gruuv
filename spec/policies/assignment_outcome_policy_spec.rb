require 'rails_helper'
require 'ostruct'

RSpec.describe AssignmentOutcomePolicy, type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:assignment_outcome) { create(:assignment_outcome, assignment: assignment) }
  
  let(:admin) { create(:person, :admin) }
  let(:maap_person) { create(:person) }
  let(:regular_person) { create(:person) }
  
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: organization) }
  let(:maap_teammate) { CompanyTeammate.create!(person: maap_person, organization: organization, can_manage_maap: true) }
  let(:regular_teammate) { CompanyTeammate.create!(person: regular_person, organization: organization) }
  
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }
  let(:pundit_user_maap) { OpenStruct.new(user: maap_teammate, impersonating_teammate: nil) }
  let(:pundit_user_regular) { OpenStruct.new(user: regular_teammate, impersonating_teammate: nil) }

  describe 'show?' do
    it 'allows admin to view' do
      policy = AssignmentOutcomePolicy.new(pundit_user_admin, assignment_outcome)
      expect(policy.show?).to be true
    end

    it 'allows teammate in same organization to view' do
      policy = AssignmentOutcomePolicy.new(pundit_user_regular, assignment_outcome)
      expect(policy.show?).to be true
    end

    it 'denies teammate in different organization' do
      other_org = create(:organization, :company)
      other_teammate = CompanyTeammate.create!(person: regular_person, organization: other_org)
      pundit_user_other = OpenStruct.new(user: other_teammate, impersonating_teammate: nil)
      policy = AssignmentOutcomePolicy.new(pundit_user_other, assignment_outcome)
      expect(policy.show?).to be false
    end
  end

  describe 'edit? and update?' do
    it 'allows admin to edit' do
      policy = AssignmentOutcomePolicy.new(pundit_user_admin, assignment_outcome)
      expect(policy.edit?).to be true
      expect(policy.update?).to be true
    end

    it 'allows teammate with MAAP permission to edit' do
      policy = AssignmentOutcomePolicy.new(pundit_user_maap, assignment_outcome)
      expect(policy.edit?).to be true
      expect(policy.update?).to be true
    end

    it 'denies regular teammate without MAAP permission' do
      policy = AssignmentOutcomePolicy.new(pundit_user_regular, assignment_outcome)
      expect(policy.edit?).to be false
      expect(policy.update?).to be false
    end

    it 'denies teammate in different organization' do
      other_org = create(:organization, :company)
      other_teammate = CompanyTeammate.create!(person: maap_person, organization: other_org, can_manage_maap: true)
      pundit_user_other = OpenStruct.new(user: other_teammate, impersonating_teammate: nil)
      policy = AssignmentOutcomePolicy.new(pundit_user_other, assignment_outcome)
      expect(policy.edit?).to be false
      expect(policy.update?).to be false
    end
  end
end
