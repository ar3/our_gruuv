require 'rails_helper'
require 'ostruct'

RSpec.describe AspirationPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:maap_user) { create(:person) }
  let(:aspiration) { create(:aspiration, organization: organization) }

  let(:pundit_user_maap) { OpenStruct.new(user: maap_user, pundit_organization: organization) }
  let(:pundit_user_person) { OpenStruct.new(user: person, pundit_organization: organization) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin, pundit_organization: organization) }

  before do
    # Grant MAAP permissions to maap_user for organization
    create(:teammate, 
           person: maap_user, 
           organization: organization, 
           can_manage_maap: true)
    
    # Create regular teammate for person
    create(:teammate, 
           person: person, 
           organization: organization, 
           can_manage_maap: false)
  end

  describe 'index?' do
    context 'when user is a regular teammate' do
      it 'allows access' do
        policy = AspirationPolicy.new(pundit_user_person, Aspiration)
        expect(policy.index?).to be true
      end
    end

    context 'when user has MAAP permissions' do
      it 'allows access' do
        policy = AspirationPolicy.new(pundit_user_maap, Aspiration)
        expect(policy.index?).to be true
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AspirationPolicy.new(pundit_user_admin, Aspiration)
        expect(policy.index?).to be true
      end
    end
  end

  describe 'show?' do
    context 'when user is a regular teammate' do
      it 'allows access' do
        policy = AspirationPolicy.new(person, aspiration)
        expect(policy.show?).to be true
      end
    end

    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AspirationPolicy.new(maap_user, aspiration)
        expect(policy.show?).to be true
      end
    end

    context 'when user lacks MAAP permissions for the organization' do
      it 'allows access (viewing is permitted for all teammates)' do
        policy = AspirationPolicy.new(person, aspiration)
        expect(policy.show?).to be true
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AspirationPolicy.new(admin, aspiration)
        expect(policy.show?).to be true
      end
    end
  end

  describe 'create?' do
    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AspirationPolicy.new(pundit_user_maap, Aspiration)
        expect(policy.create?).to be true
      end
    end

    context 'when user is a regular teammate' do
      it 'denies access' do
        policy = AspirationPolicy.new(pundit_user_person, Aspiration)
        expect(policy.create?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AspirationPolicy.new(pundit_user_admin, Aspiration)
        expect(policy.create?).to be true
      end
    end
  end

  describe 'update?' do
    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AspirationPolicy.new(maap_user, aspiration)
        expect(policy.update?).to be true
      end
    end

    context 'when user is a regular teammate' do
      it 'denies access' do
        policy = AspirationPolicy.new(person, aspiration)
        expect(policy.update?).to be false
      end
    end

    context 'when user has MAAP permissions for different organization' do
      before do
        create(:teammate, 
               person: person, 
               organization: other_organization, 
               can_manage_maap: true)
      end

      it 'denies access' do
        policy = AspirationPolicy.new(person, aspiration)
        expect(policy.update?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AspirationPolicy.new(admin, aspiration)
        expect(policy.update?).to be true
      end
    end
  end

  describe 'destroy?' do
    context 'when user has MAAP permissions for the organization' do
      it 'allows access' do
        policy = AspirationPolicy.new(maap_user, aspiration)
        expect(policy.destroy?).to be true
      end
    end

    context 'when user is a regular teammate' do
      it 'denies access' do
        policy = AspirationPolicy.new(person, aspiration)
        expect(policy.destroy?).to be false
      end
    end

    context 'when user is admin' do
      it 'allows access' do
        policy = AspirationPolicy.new(admin, aspiration)
        expect(policy.destroy?).to be true
      end
    end
  end

  describe 'scope' do
    let!(:aspiration1) { create(:aspiration, organization: organization) }
    let!(:aspiration2) { create(:aspiration, organization: organization) }
    let!(:other_org_aspiration) { create(:aspiration, organization: other_organization) }

    context 'when user is a regular teammate' do
      it 'returns aspirations for that organization' do
        policy = AspirationPolicy::Scope.new(pundit_user_person, Aspiration)
        expect(policy.resolve).to include(aspiration1, aspiration2)
        expect(policy.resolve).not_to include(other_org_aspiration)
      end
    end

    context 'when user has MAAP permissions for organization' do
      it 'returns aspirations for that organization' do
        policy = AspirationPolicy::Scope.new(pundit_user_maap, Aspiration)
        expect(policy.resolve).to include(aspiration1, aspiration2)
        expect(policy.resolve).not_to include(other_org_aspiration)
      end
    end

    context 'when user is admin' do
      it 'returns all aspirations' do
        policy = AspirationPolicy::Scope.new(pundit_user_admin, Aspiration)
        expect(policy.resolve).to include(aspiration1, aspiration2, other_org_aspiration)
      end
    end
  end
end
