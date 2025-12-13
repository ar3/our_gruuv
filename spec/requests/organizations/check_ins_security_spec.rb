require 'rails_helper'

RSpec.describe 'Check-In Security', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:other_organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:person_teammate) { create(:teammate, person: person, organization: organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:employment_manager) { create(:person) }
  let(:employment_manager_teammate) { create(:teammate, person: employment_manager, organization: organization, can_manage_employment: true) }
  let(:regular_teammate_person) { create(:person) }
  let(:regular_teammate) { create(:teammate, person: regular_teammate_person, organization: organization) }

  before do
    # Create active employment for the person
    create(:employment_tenure, teammate: person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    person_teammate.update!(first_employed_at: 1.year.ago)
    # Create active employment for manager
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    # Create active employment for employment manager
    create(:employment_tenure, teammate: employment_manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    employment_manager_teammate.update!(first_employed_at: 1.year.ago)
    # Create active employment for regular teammate
    create(:employment_tenure, teammate: regular_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    regular_teammate.update!(first_employed_at: 1.year.ago)
    # Set manager relationship
    person_teammate.employment_tenures.first.update!(manager: manager)
  end

  describe 'GET /organizations/:organization_id/people/:person_id/check_ins' do
    context 'when user is the person themselves' do
      before do
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'allows access' do
        get organization_company_teammate_check_ins_path(organization, person_teammate)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is the manager of the person' do
      before do
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows access' do
        get organization_company_teammate_check_ins_path(organization, person_teammate)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user has employment management permissions' do
      before do
        sign_in_as_teammate_for_request(employment_manager, organization)
      end

      it 'allows access' do
        get organization_company_teammate_check_ins_path(organization, person_teammate)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is unauthenticated' do
      it 'redirects to login' do
        get organization_company_teammate_check_ins_path(organization, person_teammate)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is regular teammate (not manager, no permissions)' do
      before do
        sign_in_as_teammate_for_request(regular_teammate_person, organization)
      end

      it 'denies access' do
        get organization_company_teammate_check_ins_path(organization, person_teammate)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is from different organization' do
      let(:other_org_person) { create(:person) }
      let(:other_org_teammate) { create(:teammate, person: other_org_person, organization: other_organization) }

      before do
        create(:employment_tenure, teammate: other_org_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
        other_org_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(other_org_person, other_organization)
      end

      it 'denies access' do
        get organization_company_teammate_check_ins_path(organization, person_teammate)
        expect(response).to have_http_status(:redirect)
        # User from different organization is redirected to organizations_path by ensure_teammate_matches_organization
        expect(response).to redirect_to(organizations_path)
      end
    end
  end
end

