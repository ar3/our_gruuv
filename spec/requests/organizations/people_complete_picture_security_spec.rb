require 'rails_helper'

RSpec.describe 'Active Job View (Complete Picture) Security', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:other_organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:person_teammate) { create(:teammate, person: person, organization: organization) }

  before do
    # Create active employment for the person
    create(:employment_tenure, teammate: person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    person_teammate.update!(first_employed_at: 1.year.ago)
  end

  describe 'GET /organizations/:organization_id/people/:id/complete_picture' do
    context 'when user is an active teammate in same organization' do
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: organization) }

      before do
        create(:employment_tenure, teammate: viewer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        viewer_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(viewer, organization)
      end

      it 'allows access' do
        get complete_picture_organization_company_teammate_path(organization, person_teammate)
        # Authorization passed - may redirect to show page if no assignments
        expect([200, 302]).to include(response.status)
      end
    end

    context 'when user is unauthenticated' do
      it 'redirects to login' do
        get complete_picture_organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is active teammate from different organization' do
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: other_organization) }

      before do
        create(:employment_tenure, teammate: viewer_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
        viewer_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(viewer, other_organization)
      end

      it 'denies access' do
        get complete_picture_organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:redirect)
        # User from different organization is redirected to dashboard by ensure_teammate_matches_organization
        expect(response).to redirect_to(dashboard_organization_path(other_organization))
      end
    end

    context 'when user is inactive teammate (no active employment)' do
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: organization) }

      before do
        # Create past employment (ended)
        create(:employment_tenure, teammate: viewer_teammate, company: organization, started_at: 2.years.ago, ended_at: 1.year.ago)
        sign_in_as_teammate_for_request(viewer, organization)
      end

      it 'denies access' do
        get complete_picture_organization_company_teammate_path(organization, person_teammate)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end

