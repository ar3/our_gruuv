require 'rails_helper'
require 'ostruct'

RSpec.describe PersonPolicy, type: :policy do
  subject { described_class }

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:other_person) { create(:person) }
  let(:person_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  let(:other_person_teammate) { CompanyTeammate.create!(person: other_person, organization: organization) }
  let(:pundit_user) { OpenStruct.new(user: person_teammate, impersonating_teammate: nil) }
  let(:other_pundit_user) { OpenStruct.new(user: other_person_teammate, impersonating_teammate: nil) }

  permissions :show? do
    it "allows users to view their own profile" do
      expect(subject).to permit(pundit_user, person)
    end

    it "denies users from viewing other profiles" do
      expect(subject).not_to permit(pundit_user, other_person)
    end
  end

  permissions :edit? do
    it "allows users to edit their own profile" do
      expect(subject).to permit(pundit_user, person)
    end

    it "denies regular users from editing other profiles" do
      expect(subject).not_to permit(pundit_user, other_person)
    end

    context "when user has employment management permissions" do
      let(:manager) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization, can_manage_employment: true) }
      let(:manager_pundit_user) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }
      
      before do
        # Create employment tenure for manager
        create(:employment_tenure, teammate: manager_teammate, company: organization)
        # Create employment tenure for other_person
        create(:employment_tenure, teammate: other_person_teammate, company: organization)
      end

      it "allows managers with employment management permissions to edit other profiles" do
        expect(subject).to permit(manager_pundit_user, other_person)
      end
    end

    context "when user is in managerial hierarchy" do
      let(:direct_manager) { create(:person) }
      let(:direct_manager_teammate) { CompanyTeammate.create!(person: direct_manager, organization: organization) }
      let(:direct_manager_pundit_user) { OpenStruct.new(user: direct_manager_teammate, impersonating_teammate: nil) }
      let(:grand_manager) { create(:person) }
      let(:grand_manager_teammate) { CompanyTeammate.create!(person: grand_manager, organization: organization) }
      let(:grand_manager_pundit_user) { OpenStruct.new(user: grand_manager_teammate, impersonating_teammate: nil) }
      let(:direct_manager_employment) { create(:employment_tenure, teammate: direct_manager_teammate, company: organization, manager: grand_manager) }
      let(:grand_manager_employment) { create(:employment_tenure, teammate: grand_manager_teammate, company: organization) }
      let(:employee_employment) { create(:employment_tenure, teammate: other_person_teammate, company: organization, manager: direct_manager) }
      
      before do
        direct_manager_employment
        grand_manager_employment
        employee_employment
      end

      it "allows direct managers in hierarchy to edit their employees' profiles" do
        expect(subject).to permit(direct_manager_pundit_user, other_person)
      end

      it "allows indirect managers (grand managers) in hierarchy to edit their employees' profiles" do
        expect(subject).to permit(grand_manager_pundit_user, other_person)
      end
    end
  end

  permissions :update? do
    it "allows users to update their own profile" do
      expect(subject).to permit(pundit_user, person)
    end

    it "denies regular users from updating other profiles" do
      expect(subject).not_to permit(pundit_user, other_person)
    end

    context "when user has employment management permissions" do
      let(:manager) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization, can_manage_employment: true) }
      let(:manager_pundit_user) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }
      
      before do
        # Create employment tenure for manager
        create(:employment_tenure, teammate: manager_teammate, company: organization)
        # Create employment tenure for other_person
        create(:employment_tenure, teammate: other_person_teammate, company: organization)
      end

      it "allows managers with employment management permissions to update other profiles" do
        expect(subject).to permit(manager_pundit_user, other_person)
      end
    end

    context "when user is in managerial hierarchy" do
      let(:direct_manager) { create(:person) }
      let(:direct_manager_teammate) { CompanyTeammate.create!(person: direct_manager, organization: organization) }
      let(:direct_manager_pundit_user) { OpenStruct.new(user: direct_manager_teammate, impersonating_teammate: nil) }
      let(:grand_manager) { create(:person) }
      let(:grand_manager_teammate) { CompanyTeammate.create!(person: grand_manager, organization: organization) }
      let(:grand_manager_pundit_user) { OpenStruct.new(user: grand_manager_teammate, impersonating_teammate: nil) }
      let(:direct_manager_employment) { create(:employment_tenure, teammate: direct_manager_teammate, company: organization, manager: grand_manager) }
      let(:grand_manager_employment) { create(:employment_tenure, teammate: grand_manager_teammate, company: organization) }
      let(:employee_employment) { create(:employment_tenure, teammate: other_person_teammate, company: organization, manager: direct_manager) }
      
      before do
        direct_manager_employment
        grand_manager_employment
        employee_employment
      end

      it "allows direct managers in hierarchy to update their employees' profiles" do
        expect(subject).to permit(direct_manager_pundit_user, other_person)
      end

      it "allows indirect managers (grand managers) in hierarchy to update their employees' profiles" do
        expect(subject).to permit(grand_manager_pundit_user, other_person)
      end
    end
  end

  permissions :create? do
    it "allows anyone to create a person" do
      expect(subject).to permit(pundit_user, Person.new)
    end
  end

  permissions :destroy? do
    it "denies users from destroying their own profile" do
      expect(subject).not_to permit(pundit_user, person)
    end

    it "denies users from destroying other profiles" do
      expect(subject).not_to permit(pundit_user, other_person)
    end
  end

  permissions :view_other_companies? do
    it "allows users to view their own other companies" do
      expect(subject).to permit(pundit_user, person)
    end

    it "allows admins to view any person's other companies" do
      admin_person = create(:person, :admin)
      admin_teammate = CompanyTeammate.create!(person: admin_person, organization: organization)
      admin_pundit_user = OpenStruct.new(user: admin_teammate, impersonating_teammate: nil)
      expect(subject).to permit(admin_pundit_user, other_person)
    end

    it "denies users from viewing other people's companies" do
      expect(subject).not_to permit(pundit_user, other_person)
    end
  end

  permissions :public? do
    it "allows anyone to access public view (unauthenticated)" do
      unauthenticated_user = OpenStruct.new(user: nil, impersonating_teammate: nil)
      expect(subject).to permit(unauthenticated_user, person)
    end

    it "allows authenticated users to access public view" do
      expect(subject).to permit(pundit_user, person)
    end

    it "allows users from different organizations to access public view" do
      other_org = create(:organization, :company)
      other_org_teammate = CompanyTeammate.create!(person: person, organization: other_org)
      other_org_pundit_user = OpenStruct.new(user: other_org_teammate, impersonating_teammate: nil)
      expect(subject).to permit(other_org_pundit_user, other_person)
    end
  end

  permissions :teammate? do
    let(:other_organization) { create(:organization, :company) }
    let(:viewer_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
    let(:viewer_pundit_user) { OpenStruct.new(user: viewer_teammate, impersonating_teammate: nil) }

    before do
      # Set first_employed_at for viewer_teammate (required for employed? check)
      viewer_teammate.update!(first_employed_at: 1.year.ago)
      # Create active employment for viewer
      create(:employment_tenure, teammate: viewer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      # Create active employment for other_person in same org
      create(:employment_tenure, teammate: other_person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    end

    it "allows active teammate in same organization to view" do
      expect(subject).to permit(viewer_pundit_user, other_person)
    end

    it "denies unauthenticated users" do
      unauthenticated_user = OpenStruct.new(user: nil, impersonating_teammate: nil)
      expect(subject).not_to permit(unauthenticated_user, person)
    end

    it "denies active teammate from different organization" do
      other_org_teammate = CompanyTeammate.create!(person: person, organization: other_organization)
      create(:employment_tenure, teammate: other_org_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
      other_org_pundit_user = OpenStruct.new(user: other_org_teammate, impersonating_teammate: nil)
      expect(subject).not_to permit(other_org_pundit_user, other_person)
    end

    it "denies inactive teammate (no active employment)" do
      inactive_person = create(:person)
      inactive_teammate = CompanyTeammate.create!(person: inactive_person, organization: organization)
      # Create past employment (ended)
      create(:employment_tenure, teammate: inactive_teammate, company: organization, started_at: 2.years.ago, ended_at: 1.year.ago)
      inactive_pundit_user = OpenStruct.new(user: inactive_teammate, impersonating_teammate: nil)
      expect(subject).not_to permit(inactive_pundit_user, other_person)
    end

    it "denies when person has no employment in organization" do
      person_without_employment = create(:person)
      expect(subject).not_to permit(viewer_pundit_user, person_without_employment)
    end

    it "allows admin bypass when admin is not impersonating" do
      admin_person = create(:person, :admin)
      admin_teammate = CompanyTeammate.create!(person: admin_person, organization: organization)
      admin_pundit_user = OpenStruct.new(user: admin_teammate, impersonating_teammate: nil)
      expect(subject).to permit(admin_pundit_user, other_person)
    end

    context "when admin is impersonating regular user" do
      let(:admin_person) { create(:person, :admin) }
      let(:admin_teammate) { CompanyTeammate.create!(person: admin_person, organization: organization) }

      before do
        # Set first_employed_at for viewer_teammate (required for employed? check)
        viewer_teammate.update!(first_employed_at: 1.year.ago)
        create(:employment_tenure, teammate: admin_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      end

      it "allows access if impersonated user is active teammate (uses impersonated user's permissions)" do
        impersonated_pundit_user = OpenStruct.new(
          user: viewer_teammate,       # The impersonated user
          impersonating_teammate: admin_teammate    # The admin doing the impersonating
        )
        expect(subject).to permit(impersonated_pundit_user, other_person)
      end

      it "denies access if impersonated user is inactive" do
        inactive_person = create(:person)
        inactive_teammate = CompanyTeammate.create!(person: inactive_person, organization: organization)
        create(:employment_tenure, teammate: inactive_teammate, company: organization, started_at: 2.years.ago, ended_at: 1.year.ago)
        impersonated_pundit_user = OpenStruct.new(
          user: inactive_teammate,     # The impersonated user (inactive)
          impersonating_teammate: admin_teammate    # The admin doing the impersonating
        )
        expect(subject).not_to permit(impersonated_pundit_user, other_person)
      end
    end
  end

  permissions :view_check_ins? do
    let(:manager) { create(:person) }
    let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }
    let(:manager_pundit_user) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }
    let(:employment_manager) { create(:person) }
    let(:employment_manager_teammate) { CompanyTeammate.create!(person: employment_manager, organization: organization, can_manage_employment: true) }
    let(:employment_manager_pundit_user) { OpenStruct.new(user: employment_manager_teammate, impersonating_teammate: nil) }
    let(:regular_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
    let(:regular_pundit_user) { OpenStruct.new(user: regular_teammate, impersonating_teammate: nil) }
    let(:other_organization) { create(:organization, :company) }

    before do
      # Create active employment for manager
      create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      # Create active employment for employment manager
      create(:employment_tenure, teammate: employment_manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      # Create active employment for regular teammate
      create(:employment_tenure, teammate: regular_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      # Create active employment for other_person and set manager
      create(:employment_tenure, teammate: other_person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil, manager: manager)
    end

    it "allows person themselves to view their check-ins" do
      person_self_pundit_user = OpenStruct.new(user: regular_teammate, impersonating_teammate: nil)
      policy = PersonPolicy.new(person_self_pundit_user, person)
      # Set organization context
      allow(policy).to receive(:actual_organization).and_return(organization)
      expect(policy.view_check_ins?).to be true
    end

    it "allows direct manager of person to view check-ins" do
      policy = PersonPolicy.new(manager_pundit_user, other_person)
      allow(policy).to receive(:actual_organization).and_return(organization)
      expect(policy.view_check_ins?).to be true
    end

    it "allows indirect manager (grand manager) of person to view check-ins" do
      grand_manager = create(:person)
      grand_manager_teammate = CompanyTeammate.create!(person: grand_manager, organization: organization)
      grand_manager_pundit_user = OpenStruct.new(user: grand_manager_teammate, impersonating_teammate: nil)
      
      # Create employment for grand manager
      create(:employment_tenure, teammate: grand_manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      # Update existing manager's employment to have grand manager as manager
      manager_tenure = EmploymentTenure.find_by(teammate: manager_teammate, company: organization)
      manager_tenure.update!(manager: grand_manager)
      
      policy = PersonPolicy.new(grand_manager_pundit_user, other_person)
      allow(policy).to receive(:actual_organization).and_return(organization)
      expect(policy.view_check_ins?).to be true
    end

    it "allows user with employment management permissions to view check-ins" do
      policy = PersonPolicy.new(employment_manager_pundit_user, other_person)
      allow(policy).to receive(:actual_organization).and_return(organization)
      expect(policy.view_check_ins?).to be true
    end

    it "denies unauthenticated users" do
      unauthenticated_user = OpenStruct.new(user: nil, impersonating_teammate: nil)
      policy = PersonPolicy.new(unauthenticated_user, person)
      allow(policy).to receive(:actual_organization).and_return(organization)
      expect(policy.view_check_ins?).to be false
    end

    it "denies regular teammate (not manager, no permissions)" do
      policy = PersonPolicy.new(regular_pundit_user, other_person)
      allow(policy).to receive(:actual_organization).and_return(organization)
      expect(policy.view_check_ins?).to be false
    end

    it "denies user from different organization" do
      other_org_teammate = CompanyTeammate.create!(person: person, organization: other_organization)
      create(:employment_tenure, teammate: other_org_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
      other_org_pundit_user = OpenStruct.new(user: other_org_teammate, impersonating_teammate: nil)
      policy = PersonPolicy.new(other_org_pundit_user, other_person)
      allow(policy).to receive(:actual_organization).and_return(other_organization)
      expect(policy.view_check_ins?).to be false
    end

    it "allows admin bypass when admin is not impersonating" do
      admin_person = create(:person, :admin)
      admin_teammate = CompanyTeammate.create!(person: admin_person, organization: organization)
      admin_pundit_user = OpenStruct.new(user: admin_teammate, impersonating_teammate: nil)
      policy = PersonPolicy.new(admin_pundit_user, other_person)
      allow(policy).to receive(:actual_organization).and_return(organization)
      expect(policy.view_check_ins?).to be true
    end

    context "when admin is impersonating regular user" do
      let(:admin_person) { create(:person, :admin) }
      let(:admin_teammate) { CompanyTeammate.create!(person: admin_person, organization: organization) }

      before do
        create(:employment_tenure, teammate: admin_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      end

      it "denies access (uses impersonated user's permissions, not admin's)" do
        impersonated_pundit_user = OpenStruct.new(
          user: regular_teammate,      # The impersonated user
          impersonating_teammate: admin_teammate     # The admin doing the impersonating
        )
        policy = PersonPolicy.new(impersonated_pundit_user, other_person)
        allow(policy).to receive(:actual_organization).and_return(organization)
        expect(policy.view_check_ins?).to be false
      end

      it "allows access if impersonated user is the target person" do
        impersonated_pundit_user = OpenStruct.new(
          user: regular_teammate,      # The impersonated user (same as target)
          impersonating_teammate: admin_teammate     # The admin doing the impersonating
        )
        policy = PersonPolicy.new(impersonated_pundit_user, person)
        allow(policy).to receive(:actual_organization).and_return(organization)
        expect(policy.view_check_ins?).to be true
      end
    end
  end

  permissions :audit? do
    let(:maap_manager) { create(:person) }
    let(:maap_teammate) { CompanyTeammate.create!(person: maap_manager, organization: organization, can_manage_maap: true) }
    let(:regular_user) { create(:person) }
    let(:regular_teammate) { CompanyTeammate.create!(person: regular_user, organization: organization) }
    let(:pundit_user_with_org) { OpenStruct.new(user: maap_teammate, impersonating_teammate: nil) }
    let(:pundit_user_without_org) { OpenStruct.new(user: maap_teammate, impersonating_teammate: nil) }

    before do
      # Create active employment tenure for maap_teammate
      create(:employment_tenure, teammate: maap_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    end

    it "denies users with MAAP management permissions for the organization" do
      policy = PersonPolicy.new(pundit_user_with_org, person)
      expect(policy.audit?).to be false
    end

    it "allows users to view their own audit" do
      policy = PersonPolicy.new(pundit_user_with_org, maap_manager)
      expect(policy.audit?).to be true
    end

    it "denies users without MAAP management permissions" do
      regular_pundit_user = OpenStruct.new(user: regular_teammate, impersonating_teammate: nil)
      policy = PersonPolicy.new(regular_pundit_user, person)
      expect(policy.audit?).to be false
    end

    it "denies access when user is not in managerial hierarchy" do
      # MAAP manager trying to view someone else's audit (not in hierarchy)
      policy = PersonPolicy.new(pundit_user_without_org, person)
      expect(policy.audit?).to be false
    end
  end

  permissions :change_employment? do
    before do
      # Create active employment tenure for person
      create(:employment_tenure, teammate: person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    end

    it "denies regular users from changing their own employment" do
      expect(subject).not_to permit(pundit_user, person)
    end

    context "when user has manage employment permission" do
      let(:manager) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization, can_manage_employment: true) }
      let(:manager_pundit_user) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }
      
      before do
        # Create active employment tenure for manager
        create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      end

      it "allows users with manage employment permission to change their own employment" do
        expect(subject).to permit(manager_pundit_user, manager)
      end

      it "allows users with manage employment permission to change others' employment" do
        expect(subject).to permit(manager_pundit_user, other_person)
      end
    end

    context "when user is in managerial hierarchy" do
      let(:direct_manager) { create(:person) }
      let(:direct_manager_teammate) { CompanyTeammate.create!(person: direct_manager, organization: organization) }
      let(:direct_manager_pundit_user) { OpenStruct.new(user: direct_manager_teammate, impersonating_teammate: nil) }
      let(:grand_manager) { create(:person) }
      let(:grand_manager_teammate) { CompanyTeammate.create!(person: grand_manager, organization: organization) }
      let(:grand_manager_pundit_user) { OpenStruct.new(user: grand_manager_teammate, impersonating_teammate: nil) }
      
      before do
        # Create employment tenures with manager relationships
        create(:employment_tenure, teammate: direct_manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil, manager: grand_manager)
        create(:employment_tenure, teammate: grand_manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        create(:employment_tenure, teammate: other_person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil, manager: direct_manager)
      end

      it "allows direct managers in hierarchy to change their employees' employment" do
        expect(subject).to permit(direct_manager_pundit_user, other_person)
      end

      it "allows indirect managers (grand managers) in hierarchy to change their employees' employment" do
        expect(subject).to permit(grand_manager_pundit_user, other_person)
      end
    end

    it "denies regular users from changing others' employment" do
      expect(subject).not_to permit(pundit_user, other_person)
    end

    it "allows admin bypass" do
      admin_person = create(:person, :admin)
      admin_teammate = CompanyTeammate.create!(person: admin_person, organization: organization)
      admin_pundit_user = OpenStruct.new(user: admin_teammate, impersonating_teammate: nil)
      expect(subject).to permit(admin_pundit_user, person)
      expect(subject).to permit(admin_pundit_user, other_person)
    end

    context "when user is terminated" do
      let(:terminated_person) { create(:person) }
      let(:terminated_teammate) { CompanyTeammate.create!(person: terminated_person, organization: organization, first_employed_at: 1.year.ago, last_terminated_at: 1.day.ago) }
      let(:terminated_pundit_user) { OpenStruct.new(user: terminated_teammate, impersonating_teammate: nil) }

      before do
        create(:employment_tenure, teammate: terminated_teammate, company: organization, started_at: 1.year.ago, ended_at: 1.day.ago)
      end

      it "denies terminated users from changing employment" do
        expect(subject).not_to permit(terminated_pundit_user, person)
        expect(subject).not_to permit(terminated_pundit_user, other_person)
      end
    end
  end

  describe "scope" do
    let!(:person1) { create(:person) }
    let!(:person2) { create(:person) }
    let(:person1_teammate) { CompanyTeammate.create!(person: person1, organization: organization) }
    let(:pundit_user1) { OpenStruct.new(user: person1_teammate, impersonating_teammate: nil) }

    it "shows only the user's own profile" do
      scope = PersonPolicy::Scope.new(pundit_user1, Person).resolve
      expect(scope).to include(person1)
      expect(scope).not_to include(person2)
    end
  end
end
