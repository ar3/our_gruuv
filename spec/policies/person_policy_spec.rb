require 'rails_helper'

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
