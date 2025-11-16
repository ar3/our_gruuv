require 'rails_helper'

RSpec.describe 'Teammate View Security', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:other_organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:person_teammate) { create(:teammate, person: person, organization: organization) }

  before do
    # Create active employment for the person
    create(:employment_tenure, teammate: person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  describe 'GET /organizations/:organization_id/people/:id/teammate' do
    context 'when user is an active teammate in same organization' do
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: organization) }

      before do
        create(:employment_tenure, teammate: viewer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        sign_in_as_teammate_for_request(viewer, organization)
      end

      it 'allows access' do
        get teammate_organization_person_path(organization, person)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is unauthenticated' do
      it 'redirects to login' do
        get teammate_organization_person_path(organization, person)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is active teammate from different organization' do
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: other_organization) }

      before do
        create(:employment_tenure, teammate: viewer_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
        sign_in_as_teammate_for_request(viewer, other_organization)
      end

      it 'denies access' do
        get teammate_organization_person_path(organization, person)
        expect(response).to have_http_status(:redirect)
        # Should redirect to public view per ApplicationController#user_not_authorized
        expect(response).to redirect_to(public_person_path(person))
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
        get teammate_organization_person_path(organization, person)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(public_person_path(person))
      end
    end

    context 'when person has no employment in organization' do
      let(:person_without_employment) { create(:person) }
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: organization) }

      before do
        # Person has teammate but no employment
        create(:teammate, person: person_without_employment, organization: organization)
        create(:employment_tenure, teammate: viewer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        sign_in_as_teammate_for_request(viewer, organization)
      end

      it 'denies access' do
        get teammate_organization_person_path(organization, person_without_employment)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(public_person_path(person_without_employment))
      end
    end
  end
end

