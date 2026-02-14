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
  let(:prompts_teammate) { CompanyTeammate.create!(person: person, organization: organization, can_manage_prompts: true, first_employed_at: 1.month.ago, last_terminated_at: nil) }
  let(:customize_company_teammate) { CompanyTeammate.create!(person: person, organization: organization, can_customize_company: true) }
  let(:employed_teammate) { CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil) }
  let(:other_org_teammate) { CompanyTeammate.create!(person: person, organization: other_organization, can_manage_maap: true) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil) }

  let(:pundit_user_maap) { OpenStruct.new(user: maap_teammate, impersonating_teammate: nil) }
  let(:pundit_user_employment) { OpenStruct.new(user: employment_teammate, impersonating_teammate: nil) }
  let(:pundit_user_create_employment) { OpenStruct.new(user: create_employment_teammate, impersonating_teammate: nil) }
  let(:pundit_user_no_permissions) { OpenStruct.new(user: no_permissions_teammate, impersonating_teammate: nil) }
  let(:pundit_user_prompts) { OpenStruct.new(user: prompts_teammate, impersonating_teammate: nil) }
  let(:pundit_user_customize_company) { OpenStruct.new(user: customize_company_teammate, impersonating_teammate: nil) }
  let(:pundit_user_employed) { OpenStruct.new(user: employed_teammate, impersonating_teammate: nil) }
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

  describe '#view_prompts?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for any teammate' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_prompts?).to be true
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_prompts?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_prompts?).to be false
      end
    end

    context 'when viewing_teammate is nil' do
      it 'returns false' do
        pundit_user_nil = OpenStruct.new(user: nil, impersonating_teammate: nil)
        policy = OrganizationPolicy.new(pundit_user_nil, organization)
        expect(policy.view_prompts?).to be false
      end
    end
  end

  describe '#view_observations?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for any teammate' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_observations?).to be true
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_observations?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_observations?).to be false
      end
    end
  end

  describe '#view_seats?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for employed teammates' do
        policy = OrganizationPolicy.new(pundit_user_employed, organization)
        expect(policy.view_seats?).to be true
      end

      it 'denies access for non-employed teammates' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_seats?).to be false
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_seats?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_seats?).to be false
      end
    end
  end

  describe '#view_goals?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for any teammate' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_goals?).to be true
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_goals?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_goals?).to be false
      end
    end
  end

  describe '#view_abilities?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for any teammate (no MAAP permission required)' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_abilities?).to be true
      end

      it 'allows access even without MAAP permission' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(pundit_user_no_permissions.user.can_manage_maap?).to be false
        expect(policy.view_abilities?).to be true
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_abilities?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_abilities?).to be false
      end
    end
  end

  describe '#view_assignments?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for any teammate' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_assignments?).to be true
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_assignments?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_assignments?).to be false
      end
    end
  end

  describe '#view_aspirations?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for any teammate' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_aspirations?).to be true
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_aspirations?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_aspirations?).to be false
      end
    end
  end

  describe '#view_prompt_templates?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for any employed teammate (nav link visibility)' do
        policy = OrganizationPolicy.new(pundit_user_employed, organization)
        expect(policy.view_prompt_templates?).to be true
      end

      it 'allows access when user has prompts permission' do
        policy = OrganizationPolicy.new(pundit_user_prompts, organization)
        expect(policy.view_prompt_templates?).to be true
      end

      it 'denies access when user is not employed' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_prompt_templates?).to be false
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_prompt_templates?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_prompt_templates?).to be false
      end
    end
  end

  describe '#check_ins_health?' do
    context 'when organization matches viewing_teammate.organization' do
      it 'allows access for any employed teammate (nav link visibility)' do
        policy = OrganizationPolicy.new(pundit_user_employed, organization)
        expect(policy.check_ins_health?).to be true
      end

      it 'denies access when user is not employed' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.check_ins_health?).to be false
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.check_ins_health?).to be true
      end
    end

    context 'when organization does not match viewing_teammate.organization' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.check_ins_health?).to be false
      end
    end
  end

  describe '#view_slack_settings?' do
    context 'when organization matches viewing_teammate.organization' do
      it 'allows access for any employed teammate (nav link visibility)' do
        policy = OrganizationPolicy.new(pundit_user_employed, organization)
        expect(policy.view_slack_settings?).to be true
      end

      it 'denies access when user is not employed' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_slack_settings?).to be false
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_slack_settings?).to be true
      end
    end

    context 'when organization does not match viewing_teammate.organization' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_slack_settings?).to be false
      end
    end
  end

  describe '#view_company_preferences?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for any employed teammate (nav link visibility)' do
        policy = OrganizationPolicy.new(pundit_user_employed, organization)
        expect(policy.view_company_preferences?).to be true
      end

      it 'denies access when user is not employed' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_company_preferences?).to be false
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_company_preferences?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_company_preferences?).to be false
      end
    end
  end

  describe '#view_bulk_sync_events?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for any teammate' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_bulk_sync_events?).to be true
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_bulk_sync_events?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_bulk_sync_events?).to be false
      end
    end
  end

  describe '#view_search?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for any teammate' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.view_search?).to be true
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.view_search?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.view_search?).to be false
      end
    end
  end

  describe '#download_company_teammates_csv?' do
    context 'when organization matches viewing_teammate.organization' do
      it 'allows access when viewing_teammate can manage employment' do
        policy = OrganizationPolicy.new(pundit_user_employment, organization)
        expect(policy.download_company_teammates_csv?).to be true
      end

      it 'denies access when viewing_teammate cannot manage employment' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.download_company_teammates_csv?).to be false
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.download_company_teammates_csv?).to be true
      end
    end

    context 'when organization does not match viewing_teammate.organization' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.download_company_teammates_csv?).to be false
      end
    end
  end

  describe '#download_bulk_csv?' do
    context 'when organization is in viewing_teammate hierarchy' do
      it 'allows access for employed teammates' do
        policy = OrganizationPolicy.new(pundit_user_employed, organization)
        expect(policy.download_bulk_csv?).to be true
      end

      it 'denies access for non-employed teammates' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.download_bulk_csv?).to be false
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.download_bulk_csv?).to be true
      end
    end

    context 'when organization is not in viewing_teammate hierarchy' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.download_bulk_csv?).to be false
      end
    end
  end

  describe '#customize_company?' do
    context 'when organization matches viewing_teammate.organization' do
      it 'delegates to viewing_teammate.can_customize_company?' do
        policy = OrganizationPolicy.new(pundit_user_customize_company, organization)
        expect(policy.customize_company?).to be true
        expect(customize_company_teammate.can_customize_company?).to be true
      end

      it 'returns false when viewing_teammate cannot customize company' do
        policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
        expect(policy.customize_company?).to be false
      end

      it 'respects admin_bypass?' do
        policy = OrganizationPolicy.new(pundit_user_admin, organization)
        expect(policy.customize_company?).to be true
      end
    end

    context 'when organization does not match viewing_teammate.organization' do
      it 'returns false' do
        policy = OrganizationPolicy.new(pundit_user_other_org, organization)
        expect(policy.customize_company?).to be false
      end
    end

    context 'when viewing_teammate is nil' do
      it 'returns false' do
        pundit_user_nil = OpenStruct.new(user: nil, impersonating_teammate: nil)
        policy = OrganizationPolicy.new(pundit_user_nil, organization)
        expect(policy.customize_company?).to be false
      end
    end
  end

  describe '#view_bulk_download_history?' do
    it 'allows viewing download history for any teammate' do
      policy = OrganizationPolicy.new(pundit_user_employed, organization)
      expect(policy.view_bulk_download_history?).to be true
    end

    it 'allows viewing download history for admin' do
      policy = OrganizationPolicy.new(pundit_user_admin, organization)
      expect(policy.view_bulk_download_history?).to be true
    end

    it 'denies viewing download history for different organization' do
      policy = OrganizationPolicy.new(pundit_user_other_org, organization)
      expect(policy.view_bulk_download_history?).to be false
    end
  end

  describe '#download_any_bulk_download?' do
    it 'allows download for admin' do
      policy = OrganizationPolicy.new(pundit_user_admin, organization)
      expect(policy.download_any_bulk_download?).to be true
    end

    it 'allows download for employment manager' do
      policy = OrganizationPolicy.new(pundit_user_employment, organization)
      expect(policy.download_any_bulk_download?).to be true
    end

    it 'denies download for regular teammate' do
      policy = OrganizationPolicy.new(pundit_user_employed, organization)
      expect(policy.download_any_bulk_download?).to be false
    end
  end

  describe '#download_own_bulk_download?' do
    it 'allows download for any teammate' do
      policy = OrganizationPolicy.new(pundit_user_employed, organization)
      expect(policy.download_own_bulk_download?).to be true
    end

    it 'allows download for admin' do
      policy = OrganizationPolicy.new(pundit_user_admin, organization)
      expect(policy.download_own_bulk_download?).to be true
    end
  end

  describe '#view_assignment_flows?' do
    it 'allows viewing assignment flows for employed teammate' do
      policy = OrganizationPolicy.new(pundit_user_employed, organization)
      expect(policy.view_assignment_flows?).to be true
    end

    it 'allows viewing assignment flows for admin' do
      policy = OrganizationPolicy.new(pundit_user_admin, organization)
      expect(policy.view_assignment_flows?).to be true
    end

    it 'denies viewing assignment flows for non-employed teammate' do
      policy = OrganizationPolicy.new(pundit_user_no_permissions, organization)
      expect(policy.view_assignment_flows?).to be false
    end

    it 'denies viewing assignment flows for different organization' do
      policy = OrganizationPolicy.new(pundit_user_other_org, organization)
      expect(policy.view_assignment_flows?).to be false
    end
  end
end

