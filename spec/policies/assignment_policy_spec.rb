require 'rails_helper'
require 'ostruct'

RSpec.describe AssignmentPolicy, type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:other_organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:maap_user) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }

  let(:maap_teammate) { CompanyTeammate.create!(person: maap_user, organization: organization, can_manage_maap: true) }
  let(:person_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: organization) }

  let(:pundit_user_maap) { OpenStruct.new(user: maap_teammate, impersonating_teammate: nil) }
  let(:pundit_user_person) { OpenStruct.new(user: person_teammate, impersonating_teammate: nil) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }

  describe 'show?' do
    context 'when user is in the organization hierarchy' do
      it 'allows access' do
        policy = AssignmentPolicy.new(pundit_user_maap, assignment)
        expect(policy.show?).to be true
      end
    end

    context 'when user is not in the organization hierarchy' do
      let(:other_org_teammate) { CompanyTeammate.create!(person: person, organization: other_organization) }
      let(:pundit_user_other_org) { OpenStruct.new(user: other_org_teammate, impersonating_teammate: nil) }

      it 'denies access' do
        policy = AssignmentPolicy.new(pundit_user_other_org, assignment)
        expect(policy.show?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AssignmentPolicy.new(pundit_user_admin, assignment)
        expect(policy.show?).to be true
      end
    end
  end

  describe 'create?' do
    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AssignmentPolicy.new(pundit_user_maap, Assignment.new(company: organization))
        expect(policy.create?).to be true
      end
    end

    context 'when user lacks MAAP permissions' do
      it 'denies access' do
        policy = AssignmentPolicy.new(pundit_user_person, Assignment.new(company: organization))
        expect(policy.create?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AssignmentPolicy.new(pundit_user_admin, Assignment.new(company: organization))
        expect(policy.create?).to be true
      end
    end
  end

  describe 'update?' do
    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AssignmentPolicy.new(pundit_user_maap, assignment)
        expect(policy.update?).to be true
      end
    end

    context 'when user lacks MAAP permissions for the organization' do
      it 'denies access' do
        policy = AssignmentPolicy.new(pundit_user_person, assignment)
        expect(policy.update?).to be false
      end
    end

    context 'when user has MAAP permissions for different organization' do
      let(:other_org_teammate) { CompanyTeammate.create!(person: person, organization: other_organization, can_manage_maap: true) }
      let(:pundit_user_other_org) { OpenStruct.new(user: other_org_teammate, impersonating_teammate: nil) }

      it 'denies access' do
        policy = AssignmentPolicy.new(pundit_user_other_org, assignment)
        expect(policy.update?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AssignmentPolicy.new(pundit_user_admin, assignment)
        expect(policy.update?).to be true
      end
    end
  end

  describe 'run_clarity?' do
    it 'matches update? — MAAP user allowed' do
      policy = AssignmentPolicy.new(pundit_user_maap, assignment)
      expect(policy.run_clarity?).to eq(policy.update?)
      expect(policy.run_clarity?).to be true
    end

    it 'denies when update is denied' do
      policy = AssignmentPolicy.new(pundit_user_person, assignment)
      expect(policy.run_clarity?).to be false
    end
  end

  describe 'destroy?' do
    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AssignmentPolicy.new(pundit_user_maap, assignment)
        expect(policy.destroy?).to be true
      end
    end

    context 'when user lacks MAAP permissions for the organization' do
      it 'denies access' do
        policy = AssignmentPolicy.new(pundit_user_person, assignment)
        expect(policy.destroy?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AssignmentPolicy.new(pundit_user_admin, assignment)
        expect(policy.destroy?).to be true
      end
    end
  end

  describe 'archive?' do
    it 'delegates to update?' do
      policy = AssignmentPolicy.new(pundit_user_maap, assignment)
      expect(policy.archive?).to eq(policy.update?)
    end
  end

  describe 'restore?' do
    it 'delegates to update?' do
      policy = AssignmentPolicy.new(pundit_user_maap, assignment)
      expect(policy.restore?).to eq(policy.update?)
    end
  end

  describe 'bulk_remove_from_positions? and bulk_close_assignment_tenures?' do
    let(:employment_maap_teammate) do
      CompanyTeammate.create!(person: maap_user, organization: organization, can_manage_maap: true, can_manage_employment: true)
    end
    let(:pundit_user_employment_maap) { OpenStruct.new(user: employment_maap_teammate, impersonating_teammate: nil) }

    it 'allows when user has MAAP and employment management permissions' do
      policy = AssignmentPolicy.new(pundit_user_employment_maap, assignment)
      expect(policy.bulk_remove_from_positions?).to be true
      expect(policy.bulk_close_assignment_tenures?).to be true
    end

    it 'denies when user has MAAP but not employment management permissions' do
      policy = AssignmentPolicy.new(pundit_user_maap, assignment)
      expect(policy.bulk_remove_from_positions?).to be false
      expect(policy.bulk_close_assignment_tenures?).to be false
    end

    it 'denies when user lacks MAAP permissions' do
      employment_only_teammate = CompanyTeammate.create!(
        person: person,
        organization: organization,
        can_manage_maap: false,
        can_manage_employment: true
      )
      pundit_user = OpenStruct.new(user: employment_only_teammate, impersonating_teammate: nil)
      policy = AssignmentPolicy.new(pundit_user, assignment)
      expect(policy.bulk_remove_from_positions?).to be false
      expect(policy.bulk_close_assignment_tenures?).to be false
    end
  end

  describe 'manage_consumer_assignments?' do
    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AssignmentPolicy.new(pundit_user_maap, assignment)
        expect(policy.manage_consumer_assignments?).to be true
      end
    end

    context 'when user lacks MAAP permissions for the organization' do
      it 'denies access' do
        policy = AssignmentPolicy.new(pundit_user_person, assignment)
        expect(policy.manage_consumer_assignments?).to be false
      end
    end

    context 'when user has MAAP permissions for different organization' do
      let(:other_org_teammate) { CompanyTeammate.create!(person: person, organization: other_organization, can_manage_maap: true) }
      let(:pundit_user_other_org) { OpenStruct.new(user: other_org_teammate, impersonating_teammate: nil) }

      it 'denies access' do
        policy = AssignmentPolicy.new(pundit_user_other_org, assignment)
        expect(policy.manage_consumer_assignments?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AssignmentPolicy.new(pundit_user_admin, assignment)
        expect(policy.manage_consumer_assignments?).to be true
      end
    end
  end

  describe 'scope' do
    let!(:assignment1) { create(:assignment, company: organization) }
    let!(:assignment2) { create(:assignment, company: organization) }
    let!(:other_org_assignment) { create(:assignment, company: other_organization) }

    context 'when user is in organization hierarchy' do
      it 'returns assignments for that organization' do
        policy = AssignmentPolicy::Scope.new(pundit_user_maap, Assignment)
        expect(policy.resolve).to include(assignment1, assignment2)
        expect(policy.resolve).not_to include(other_org_assignment)
      end
    end

    context 'when user is admin' do
      it 'returns all assignments' do
        policy = AssignmentPolicy::Scope.new(pundit_user_admin, Assignment)
        expect(policy.resolve).to include(assignment1, assignment2, other_org_assignment)
      end
    end
  end
end

