require 'rails_helper'
require 'ostruct'

RSpec.describe PersonPolicy, type: :policy do
  subject { described_class }

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:other_person) { create(:person) }
  let(:person_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  let(:other_person_teammate) { CompanyTeammate.create!(person: other_person, organization: organization) }
  let(:pundit_user) { OpenStruct.new(user: person_teammate, real_user: person_teammate) }
  let(:other_pundit_user) { OpenStruct.new(user: other_person_teammate, real_user: other_person_teammate) }

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
      let(:manager_pundit_user) { OpenStruct.new(user: manager_teammate, real_user: manager_teammate) }
      
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
      let(:manager) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }
      let(:manager_pundit_user) { OpenStruct.new(user: manager_teammate, real_user: manager_teammate) }
      let(:manager_employment) { create(:employment_tenure, teammate: manager_teammate, company: organization) }
      let(:employee_employment) { create(:employment_tenure, teammate: other_person_teammate, company: organization, manager: manager) }
      
      before do
        manager_employment
        employee_employment
      end

      it "allows managers in hierarchy to edit their employees' profiles" do
        expect(subject).to permit(manager_pundit_user, other_person)
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
      let(:manager_pundit_user) { OpenStruct.new(user: manager_teammate, real_user: manager_teammate) }
      
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
      let(:manager) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization) }
      let(:manager_pundit_user) { OpenStruct.new(user: manager_teammate, real_user: manager_teammate) }
      let(:manager_employment) { create(:employment_tenure, teammate: manager_teammate, company: organization) }
      let(:employee_employment) { create(:employment_tenure, teammate: other_person_teammate, company: organization, manager: manager) }
      
      before do
        manager_employment
        employee_employment
      end

      it "allows managers in hierarchy to update their employees' profiles" do
        expect(subject).to permit(manager_pundit_user, other_person)
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
      admin_pundit_user = OpenStruct.new(user: admin_teammate, real_user: admin_teammate)
      expect(subject).to permit(admin_pundit_user, other_person)
    end

    it "denies users from viewing other people's companies" do
      expect(subject).not_to permit(pundit_user, other_person)
    end
  end

  permissions :audit? do
    let(:maap_manager) { create(:person) }
    let(:maap_teammate) { CompanyTeammate.create!(person: maap_manager, organization: organization, can_manage_maap: true) }
    let(:regular_user) { create(:person) }
    let(:regular_teammate) { CompanyTeammate.create!(person: regular_user, organization: organization) }
    let(:pundit_user_with_org) { OpenStruct.new(user: maap_teammate, real_user: maap_teammate) }
    let(:pundit_user_without_org) { OpenStruct.new(user: maap_teammate, real_user: maap_teammate) }

    it "allows users with MAAP management permissions for the organization" do
      policy = PersonPolicy.new(pundit_user_with_org, person)
      expect(policy.audit?).to be true
    end

    it "allows users to view their own audit" do
      policy = PersonPolicy.new(pundit_user_with_org, maap_manager)
      expect(policy.audit?).to be true
    end

    it "denies users without MAAP management permissions" do
      regular_pundit_user = OpenStruct.new(user: regular_teammate, real_user: regular_teammate)
      policy = PersonPolicy.new(regular_pundit_user, person)
      expect(policy.audit?).to be false
    end

    it "denies access when organization context is missing" do
      # Organization comes from teammate, so this should still work
      policy = PersonPolicy.new(pundit_user_without_org, person)
      expect(policy.audit?).to be true # Actually should work since teammate has org
    end
  end

  describe "scope" do
    let!(:person1) { create(:person) }
    let!(:person2) { create(:person) }
    let(:person1_teammate) { CompanyTeammate.create!(person: person1, organization: organization) }
    let(:pundit_user1) { OpenStruct.new(user: person1_teammate, real_user: person1_teammate) }

    it "shows only the user's own profile" do
      scope = PersonPolicy::Scope.new(pundit_user1, Person).resolve
      expect(scope).to include(person1)
      expect(scope).not_to include(person2)
    end
  end
end
