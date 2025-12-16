require 'rails_helper'
require 'ostruct'

RSpec.describe AbilityPolicy, type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:other_organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:maap_user) { create(:person) }
  let(:ability) { create(:ability, organization: organization) }

  let(:maap_teammate) { CompanyTeammate.create!(person: maap_user, organization: organization, can_manage_maap: true) }
  let(:person_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: organization) }

  let(:pundit_user_maap) { OpenStruct.new(user: maap_teammate, impersonating_teammate: nil) }
  let(:pundit_user_person) { OpenStruct.new(user: person_teammate, impersonating_teammate: nil) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }

  describe 'show?' do
    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AbilityPolicy.new(pundit_user_maap, ability)
        expect(policy.show?).to be true
      end
    end

    context 'when user lacks MAAP permissions for the organization' do
      it 'denies access' do
        policy = AbilityPolicy.new(pundit_user_person, ability)
        expect(policy.show?).to be false
      end
    end

    context 'when user has MAAP permissions for different organization' do
      let(:other_org_teammate) { CompanyTeammate.create!(person: person, organization: other_organization, can_manage_maap: true) }
      let(:pundit_user_other_org) { OpenStruct.new(user: other_org_teammate, impersonating_teammate: nil) }

      it 'denies access' do
        policy = AbilityPolicy.new(pundit_user_other_org, ability)
        expect(policy.show?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AbilityPolicy.new(pundit_user_admin, ability)
        expect(policy.show?).to be true
      end
    end
  end

  describe 'create?' do
    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AbilityPolicy.new(pundit_user_maap, Ability)
        expect(policy.create?).to be true
      end
    end

    context 'when user lacks MAAP permissions' do
      it 'denies access' do
        policy = AbilityPolicy.new(pundit_user_person, Ability)
        expect(policy.create?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AbilityPolicy.new(pundit_user_admin, Ability)
        expect(policy.create?).to be true
      end
    end
  end

  describe 'update?' do
    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AbilityPolicy.new(pundit_user_maap, ability)
        expect(policy.update?).to be true
      end
    end

    context 'when user lacks MAAP permissions for the organization' do
      it 'denies access' do
        policy = AbilityPolicy.new(pundit_user_person, ability)
        expect(policy.update?).to be false
      end
    end

    context 'when user has MAAP permissions for different organization' do
      let(:other_org_teammate) { CompanyTeammate.create!(person: person, organization: other_organization, can_manage_maap: true) }
      let(:pundit_user_other_org) { OpenStruct.new(user: other_org_teammate, impersonating_teammate: nil) }

      it 'denies access' do
        policy = AbilityPolicy.new(pundit_user_other_org, ability)
        expect(policy.update?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AbilityPolicy.new(pundit_user_admin, ability)
        expect(policy.update?).to be true
      end
    end
  end

  describe 'destroy?' do
    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AbilityPolicy.new(pundit_user_maap, ability)
        expect(policy.destroy?).to be true
      end
    end

    context 'when user lacks MAAP permissions for the organization' do
      it 'denies access' do
        policy = AbilityPolicy.new(pundit_user_person, ability)
        expect(policy.destroy?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AbilityPolicy.new(pundit_user_admin, ability)
        expect(policy.destroy?).to be true
      end
    end
  end

  describe 'scope' do
    let!(:ability1) { create(:ability, organization: organization) }
    let!(:ability2) { create(:ability, organization: organization) }
    let!(:other_org_ability) { create(:ability, organization: other_organization) }

    context 'when user has MAAP permissions for organization' do
      it 'returns abilities for that organization' do
        policy = AbilityPolicy::Scope.new(pundit_user_maap, Ability)
        expect(policy.resolve).to include(ability1, ability2)
        expect(policy.resolve).not_to include(other_org_ability)
      end
    end

    context 'when user lacks MAAP permissions' do
      it 'returns empty scope' do
        policy = AbilityPolicy::Scope.new(pundit_user_person, Ability)
        expect(policy.resolve).to be_empty
      end
    end

    context 'when user is admin' do
      it 'returns all abilities' do
        policy = AbilityPolicy::Scope.new(pundit_user_admin, Ability)
        expect(policy.resolve).to include(ability1, ability2, other_org_ability)
      end
    end
  end
end
