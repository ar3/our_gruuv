require 'rails_helper'
require 'ostruct'

RSpec.describe 'Impersonation Security', type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:admin) { create(:person, :admin) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: organization) }
  let(:regular_user) { create(:person) }
  let(:regular_user_teammate) { CompanyTeammate.create!(person: regular_user, organization: organization) }
  let(:target_person) { create(:person) }
  let(:target_teammate) { CompanyTeammate.create!(person: target_person, organization: organization) }

  before do
    # Set first_employed_at for regular_user_teammate (required for employed? check)
    regular_user_teammate.update!(first_employed_at: 1.year.ago)
    # Create active employment for all users
    create(:employment_tenure, teammate: admin_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: regular_user_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: target_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  describe 'admin_bypass? when impersonating' do
    context 'when admin impersonates regular user' do
      let(:pundit_user) do
        OpenStruct.new(
          user: regular_user_teammate,  # The impersonated user
          impersonating_teammate: admin_teammate      # The admin doing the impersonating
        )
      end

      it 'returns false (uses impersonated user\'s permissions, not admin\'s)' do
        policy = PersonPolicy.new(pundit_user, target_person)
        expect(policy.send(:admin_bypass?)).to be false
      end
    end

    context 'when admin is not impersonating' do
      let(:pundit_user) do
        OpenStruct.new(
          user: admin_teammate,
          impersonating_teammate: nil
        )
      end

      it 'returns true (admin has bypass permissions)' do
        policy = PersonPolicy.new(pundit_user, target_person)
        expect(policy.send(:admin_bypass?)).to be true
      end
    end

    context 'when regular user is not impersonating' do
      let(:pundit_user) do
        OpenStruct.new(
          user: regular_user_teammate,
          impersonating_teammate: nil
        )
      end

      it 'returns false (regular user has no admin bypass)' do
        policy = PersonPolicy.new(pundit_user, target_person)
        expect(policy.send(:admin_bypass?)).to be false
      end
    end
  end

  describe 'view_check_ins? when impersonating' do
    context 'when admin impersonates regular user without permissions' do
      let(:pundit_user) do
        OpenStruct.new(
          user: regular_user_teammate,  # The impersonated user
          impersonating_teammate: admin_teammate      # The admin doing the impersonating
        )
      end

      it 'denies access (uses impersonated user\'s permissions)' do
        policy = PersonPolicy.new(pundit_user, target_person)
        allow(policy).to receive(:actual_organization).and_return(organization)
        expect(policy.view_check_ins?).to be false
      end
    end

    context 'when admin impersonates regular user who is the target person' do
      let(:pundit_user) do
        OpenStruct.new(
          user: regular_user_teammate,  # The impersonated user (same as target)
          impersonating_teammate: admin_teammate      # The admin doing the impersonating
        )
      end

      it 'allows access (person viewing themselves)' do
        policy = PersonPolicy.new(pundit_user, regular_user)
        allow(policy).to receive(:actual_organization).and_return(organization)
        expect(policy.view_check_ins?).to be true
      end
    end

    context 'when admin impersonates regular user who is manager of target' do
      let(:manager_person) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.create!(person: manager_person, organization: organization) }

      before do
        create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        manager_teammate.update!(first_employed_at: 1.year.ago)
        target_teammate.employment_tenures.first.update!(manager_teammate: manager_teammate)
        # Reload teammates to clear association cache
        manager_teammate.reload
        target_teammate.reload
      end

      let(:pundit_user) do
        OpenStruct.new(
          user: manager_teammate,  # The impersonated user (manager)
          impersonating_teammate: admin_teammate # The admin doing the impersonating
        )
      end

      it 'allows access (impersonated user is manager)' do
        policy = PersonPolicy.new(pundit_user, target_person)
        allow(policy).to receive(:actual_organization).and_return(organization)
        expect(policy.view_check_ins?).to be true
      end
    end
  end

  describe 'teammate? when impersonating' do
    context 'when admin impersonates regular user' do
      let(:pundit_user) do
        OpenStruct.new(
          user: regular_user_teammate,  # The impersonated user
          impersonating_teammate: admin_teammate      # The admin doing the impersonating
        )
      end

      it 'allows access if impersonated user is active teammate (uses impersonated user\'s permissions)' do
        policy = PersonPolicy.new(pundit_user, target_person)
        expect(policy.teammate?).to be true
      end
    end

    context 'when admin impersonates inactive user' do
      let(:inactive_user) { create(:person) }
      let(:inactive_teammate) { CompanyTeammate.create!(person: inactive_user, organization: organization) }

      before do
        # Create past employment (ended)
        create(:employment_tenure, teammate: inactive_teammate, company: organization, started_at: 2.years.ago, ended_at: 1.year.ago)
      end

      let(:pundit_user) do
        OpenStruct.new(
          user: inactive_teammate,  # The impersonated user (inactive)
          impersonating_teammate: admin_teammate  # The admin doing the impersonating
        )
      end

      it 'denies access (uses impersonated user\'s inactive status)' do
        policy = PersonPolicy.new(pundit_user, target_person)
        expect(policy.teammate?).to be false
      end
    end
  end
end

