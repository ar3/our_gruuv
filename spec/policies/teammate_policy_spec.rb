require 'rails_helper'
require 'ostruct'

RSpec.describe TeammatePolicy, type: :policy do
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

  describe 'show?' do
    it 'can be called without raising a private method error' do
      expect {
        policy = TeammatePolicy.new(pundit_user, person_teammate)
        policy.show?
      }.not_to raise_error
    end

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

    context 'when user has employment management permission' do
      let(:manager) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization, can_manage_employment: true) }
      let(:manager_pundit_user) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }

      before do
        create(:employment_tenure, teammate: manager_teammate, company: organization)
        create(:employment_tenure, teammate: other_person_teammate, company: organization)
      end

      it 'allows access' do
        expect(subject).to permit(manager_pundit_user, other_person_teammate)
      end
    end

    context 'when user is in managerial hierarchy' do
      let(:direct_manager) { create(:person) }
      let(:direct_manager_teammate) { CompanyTeammate.create!(person: direct_manager, organization: organization) }
      let(:direct_manager_pundit_user) { OpenStruct.new(user: direct_manager_teammate, impersonating_teammate: nil) }
      let(:grand_manager) { create(:person) }
      let(:grand_manager_teammate) { CompanyTeammate.create!(person: grand_manager, organization: organization) }
      let(:grand_manager_pundit_user) { OpenStruct.new(user: grand_manager_teammate, impersonating_teammate: nil) }

      before do
        direct_manager_teammate
        grand_manager_teammate
        other_person_teammate
        create(:employment_tenure, teammate: direct_manager_teammate, company: organization, manager: grand_manager)
        create(:employment_tenure, teammate: grand_manager_teammate, company: organization)
        create(:employment_tenure, teammate: other_person_teammate, company: organization, manager: direct_manager)
        direct_manager_teammate.reload
        grand_manager_teammate.reload
        other_person_teammate.reload
      end

      it 'allows direct managers in hierarchy to view their employees' do
        expect(subject).to permit(direct_manager_pundit_user, other_person_teammate)
      end

      it 'allows indirect managers (grand managers) in hierarchy to view their employees' do
        expect(subject).to permit(grand_manager_pundit_user, other_person_teammate)
      end
    end

    context 'when viewing other teammate without permission' do
      it 'denies access' do
        expect(subject).not_to permit(pundit_user, other_person_teammate)
      end
    end

    context 'when viewing_teammate is terminated' do
      let(:terminated_teammate) do
        CompanyTeammate.create!(
          person: person,
          organization: organization,
          first_employed_at: 1.year.ago,
          last_terminated_at: 1.month.ago
        )
      end
      let(:terminated_pundit_user) { OpenStruct.new(user: terminated_teammate, impersonating_teammate: nil) }

      it 'prevents terminated teammates from viewing others' do
        expect(subject).not_to permit(terminated_pundit_user, other_person_teammate)
      end

      it 'still allows terminated teammates to view themselves' do
        expect(subject).to permit(terminated_pundit_user, terminated_teammate)
      end
    end

    context 'when record is nil' do
      it 'denies access' do
        policy = TeammatePolicy.new(pundit_user, nil)
        expect(policy.show?).to be false
      end
    end

    context 'when viewing_teammate is nil' do
      let(:nil_pundit_user) { OpenStruct.new(user: nil, impersonating_teammate: nil) }

      it 'denies access' do
        policy = TeammatePolicy.new(nil_pundit_user, person_teammate)
        expect(policy.show?).to be false
      end
    end
  end
end

