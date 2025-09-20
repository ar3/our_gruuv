require 'rails_helper'
require 'ostruct'

RSpec.describe PersonPolicy, type: :policy do
  subject { described_class }

  let(:person) { create(:person) }
  let(:other_person) { create(:person) }

  permissions :show? do
    it "allows users to view their own profile" do
      expect(subject).to permit(person, person)
    end

    it "denies users from viewing other profiles" do
      expect(subject).not_to permit(person, other_person)
    end
  end

  permissions :edit? do
    it "allows users to edit their own profile" do
      expect(subject).to permit(person, person)
    end

    it "denies users from editing other profiles" do
      expect(subject).not_to permit(person, other_person)
    end
  end

  permissions :update? do
    it "allows users to update their own profile" do
      expect(subject).to permit(person, person)
    end

    it "denies users from updating other profiles" do
      expect(subject).not_to permit(person, other_person)
    end
  end

  permissions :create? do
    it "allows anyone to create a person" do
      expect(subject).to permit(person, Person.new)
    end
  end

  permissions :destroy? do
    it "denies users from destroying their own profile" do
      expect(subject).not_to permit(person, person)
    end

    it "denies users from destroying other profiles" do
      expect(subject).not_to permit(person, other_person)
    end
  end

  permissions :view_other_companies? do
    it "allows users to view their own other companies" do
      expect(subject).to permit(person, person)
    end

    it "allows admins to view any person's other companies" do
      admin_person = create(:person, :admin)
      expect(subject).to permit(admin_person, other_person)
    end

    it "denies users from viewing other people's companies" do
      expect(subject).not_to permit(person, other_person)
    end
  end

  permissions :audit? do
    let(:organization) { create(:organization, :company) }
    let(:maap_manager) { create(:person) }
    let(:maap_access) { create(:person_organization_access, person: maap_manager, organization: organization, can_manage_maap: true) }
    let(:regular_user) { create(:person) }
    let(:pundit_user_with_org) { OpenStruct.new(user: maap_manager, pundit_organization: organization) }
    let(:pundit_user_without_org) { OpenStruct.new(user: maap_manager, pundit_organization: nil) }

    before do
      maap_access
    end

    it "allows users with MAAP management permissions for the organization" do
      policy = PersonPolicy.new(pundit_user_with_org, person)
      expect(policy.audit?).to be true
    end

    it "allows users to view their own audit" do
      policy = PersonPolicy.new(pundit_user_with_org, maap_manager)
      expect(policy.audit?).to be true
    end

    it "denies users without MAAP management permissions" do
      regular_pundit_user = OpenStruct.new(user: regular_user, pundit_organization: organization)
      policy = PersonPolicy.new(regular_pundit_user, person)
      expect(policy.audit?).to be false
    end

    it "denies access when organization context is missing" do
      policy = PersonPolicy.new(pundit_user_without_org, person)
      expect(policy.audit?).to be false
    end
  end

  describe "scope" do
    let!(:person1) { create(:person) }
    let!(:person2) { create(:person) }

    it "shows only the user's own profile" do
      scope = PersonPolicy::Scope.new(person1, Person).resolve
      expect(scope).to include(person1)
      expect(scope).not_to include(person2)
    end
  end
end
