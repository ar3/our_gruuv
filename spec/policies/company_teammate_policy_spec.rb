require 'rails_helper'
require 'ostruct'

RSpec.describe CompanyTeammatePolicy, type: :policy do
  subject { described_class }

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:other_person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  
  let(:person_teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  let(:other_person_teammate) { CompanyTeammate.create!(person: other_person, organization: organization) }
  let(:admin_teammate) { CompanyTeammate.create!(person: admin, organization: organization) }
  
  let(:pundit_user) { OpenStruct.new(user: person_teammate, impersonating_teammate: nil) }
  let(:other_pundit_user) { OpenStruct.new(user: other_person_teammate, impersonating_teammate: nil) }
  let(:admin_pundit_user) { OpenStruct.new(user: admin_teammate, impersonating_teammate: nil) }

  describe 'internal?' do
    it 'can be called without raising a private method error' do
      expect {
        policy = CompanyTeammatePolicy.new(pundit_user, person_teammate)
        policy.internal?
      }.not_to raise_error
    end

    permissions :internal? do
      context 'when user is admin' do
        it 'allows access via admin bypass' do
          expect(subject).to permit(admin_pundit_user, person_teammate)
          expect(subject).to permit(admin_pundit_user, other_person_teammate)
        end
      end

      context 'when viewing own teammate record' do
        it 'allows access' do
          expect(subject).to permit(pundit_user, person_teammate)
        end
      end

      context 'when viewing teammate in same organization' do
        before do
          person_teammate.update!(first_employed_at: 1.month.ago)
          other_person_teammate.update!(first_employed_at: 1.month.ago)
          create(:employment_tenure, teammate: person_teammate, company: organization)
          create(:employment_tenure, teammate: other_person_teammate, company: organization)
        end

        it 'allows employed users to view any teammate in their organization' do
          expect(subject).to permit(pundit_user, other_person_teammate)
        end
      end

      context 'when viewing teammate in different organization' do
        let(:other_org) { create(:organization, :company) }
        let(:other_org_teammate) { CompanyTeammate.create!(person: other_person, organization: other_org) }

        before do
          person_teammate.update!(first_employed_at: 1.month.ago)
          create(:employment_tenure, teammate: person_teammate, company: organization)
        end

        it 'denies access to teammates in different organizations' do
          expect(subject).not_to permit(pundit_user, other_org_teammate)
        end
      end

      context 'when viewing_teammate is not employed' do
        let(:not_employed_person) { create(:person) }
        let(:not_employed_teammate) { CompanyTeammate.create!(person: not_employed_person, organization: organization) }
        let(:not_employed_pundit_user) { OpenStruct.new(user: not_employed_teammate, impersonating_teammate: nil) }

        it 'denies access when viewing others' do
          expect(subject).not_to permit(not_employed_pundit_user, other_person_teammate)
        end

        it 'still allows viewing own record' do
          expect(subject).to permit(not_employed_pundit_user, not_employed_teammate)
        end
      end
    end

    context 'when record is nil' do
      it 'denies access' do
        policy = CompanyTeammatePolicy.new(pundit_user, nil)
        expect(policy.internal?).to be false
      end
    end

    context 'when viewing_teammate is nil' do
      let(:nil_pundit_user) { OpenStruct.new(user: nil, impersonating_teammate: nil) }

      it 'denies access' do
        policy = CompanyTeammatePolicy.new(nil_pundit_user, person_teammate)
        expect(policy.internal?).to be false
      end
    end
  end

  describe 'view_kudos_points?' do
    permissions :view_kudos_points? do
      context 'when user is admin' do
        it 'allows access via admin bypass' do
          expect(subject).to permit(admin_pundit_user, person_teammate)
        end
      end

      context 'when viewing own teammate record' do
        it 'allows access' do
          expect(subject).to permit(pundit_user, person_teammate)
        end
      end

      context 'when viewing another teammate in same org (peer, not in hierarchy)' do
        before do
          person_teammate.update!(first_employed_at: 1.month.ago)
          other_person_teammate.update!(first_employed_at: 1.month.ago)
          create(:employment_tenure, teammate: person_teammate, company: organization)
          create(:employment_tenure, teammate: other_person_teammate, company: organization)
        end

        it 'denies access' do
          expect(subject).not_to permit(pundit_user, other_person_teammate)
        end
      end

      context 'when viewer is in managerial hierarchy of record' do
        let(:report_person) { create(:person) }
        let(:report_teammate) { CompanyTeammate.create!(person: report_person, organization: organization) }

        before do
          person_teammate.update!(first_employed_at: 1.year.ago)
          report_teammate.update!(first_employed_at: 6.months.ago)
          create(:employment_tenure, teammate: person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
          create(:employment_tenure, teammate: report_teammate, company: organization, started_at: 6.months.ago, ended_at: nil, manager_teammate: person_teammate)
        end

        it 'allows manager to view report’s highlights points' do
          expect(subject).to permit(pundit_user, report_teammate)
        end
      end

      context 'when viewer has manage_employment permission' do
        before do
          person_teammate.update!(first_employed_at: 1.month.ago, can_manage_employment: true)
          other_person_teammate.update!(first_employed_at: 1.month.ago)
          create(:employment_tenure, teammate: person_teammate, company: organization)
          create(:employment_tenure, teammate: other_person_teammate, company: organization)
        end

        it 'allows viewing any teammate’s kudos points page (peer not in hierarchy)' do
          expect(subject).to permit(pundit_user, other_person_teammate)
        end
      end
    end
  end
end
