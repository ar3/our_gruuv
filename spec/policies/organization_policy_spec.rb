require 'rails_helper'
require 'ostruct'

RSpec.describe OrganizationPolicy, type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:other_organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  
  let(:maap_teammate) { CompanyTeammate.create!(person: person, organization: organization, can_manage_maap: true) }
  let(:employment_teammate) { CompanyTeammate.create!(person: person, organization: organization, can_manage_employment: true) }
  let(:create_employment_teammate) { CompanyTeammate.create!(person: person, organization: organization, can_create_employment: true) }
  let(:no_permissions_teammate) { CompanyTeammate.create!(person: person, organization: organization, can_manage_maap: false, can_manage_employment: false, can_create_employment: false) }
  let(:other_org_teammate) { CompanyTeammate.create!(person: person, organization: other_organization, can_manage_maap: true) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: organization) }

  let(:pundit_user_maap) { OpenStruct.new(user: maap_teammate, impersonating_teammate: nil) }
  let(:pundit_user_employment) { OpenStruct.new(user: employment_teammate, impersonating_teammate: nil) }
  let(:pundit_user_create_employment) { OpenStruct.new(user: create_employment_teammate, impersonating_teammate: nil) }
  let(:pundit_user_no_permissions) { OpenStruct.new(user: no_permissions_teammate, impersonating_teammate: nil) }
  let(:pundit_user_other_org) { OpenStruct.new(user: other_org_teammate, impersonating_teammate: nil) }
  let(:pundit_user_admin) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }

  describe '#manage_maap?' do
    context 'when organization matches viewing_teammate.organization' do
      it 'delegates to viewing_teammate.can_manage_maap?' do
        policy = OrganizationPolicy.new(pundit_user_maap, organization)
        expect(policy.manage_maap?).to be true
        expect(maap_teammate.can_manage_maap?).to be true
      end

      it 'returns false when viewing_teammate cannot manage MAAP' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.manage_maap?).to be false
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.manage_maap?).to be true
      end
    end

    context 'when organization does not match viewing_teammate.organization' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.manage_maap?).to be false
      end
    end

    context 'when viewing_teammate is nil' do
      it 'returns false' do
        pundit_user_nil = OpenStruct.new(user: nil, impersonating_teammate: nil)
        policy = OrganizationPolicy.new(pundit_user_nil, organization)
        expect(policy.manage_maap?).to be false
      end
    end
  end

  describe '#manage_employment?' do
    context 'when organization matches viewing_teammate.organization' do
      it 'delegates to viewing_teammate.can_manage_employment?' do
        policy = OrganizationPolicy.new(pundit_user_employment, organization)
        expect(policy.manage_employment?).to be true
        expect(employment_teammate.can_manage_employment?).to be true
      end

      it 'returns false when viewing_teammate cannot manage employment' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.manage_employment?).to be false
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.manage_employment?).to be true
      end
    end

    context 'when organization does not match viewing_teammate.organization' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.manage_employment?).to be false
      end
    end
  end

  describe '#create_employment?' do
    context 'when organization matches viewing_teammate.organization' do
      it 'delegates to viewing_teammate.can_create_employment?' do
        policy = OrganizationPolicy.new(pundit_user_create_employment, organization)
        expect(policy.create_employment?).to be true
        expect(create_employment_teammate.can_create_employment?).to be true
      end

      it 'returns false when viewing_teammate cannot create employment' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.create_employment?).to be false
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.create_employment?).to be true
      end
    end

    context 'when organization does not match viewing_teammate.organization' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.create_employment?).to be false
      end
    end
  end

  describe 'consistency with viewing_teammate.can_*?' do
    it 'manage_maap? returns same result as viewing_teammate.can_manage_maap? when org matches' do
      policy = OrganizationPolicy.new(pundit_user_maap, organization)
      expect(policy.manage_maap?).to eq(maap_teammate.can_manage_maap?)
    end

    it 'manage_employment? returns same result as viewing_teammate.can_manage_employment? when org matches' do
      policy = OrganizationPolicy.new(pundit_user_employment, organization)
      expect(policy.manage_employment?).to eq(employment_teammate.can_manage_employment?)
    end

    it 'create_employment? returns same result as viewing_teammate.can_create_employment? when org matches' do
      policy = OrganizationPolicy.new(pundit_user_create_employment, organization)
      expect(policy.create_employment?).to eq(create_employment_teammate.can_create_employment?)
    end
  end
end

