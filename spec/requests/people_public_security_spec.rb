require 'rails_helper'

RSpec.describe 'Public Person View Security', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:other_organization) { create(:organization, :company) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe') }
  let(:person_teammate) { create(:teammate, person: person, organization: organization) }
  
  before do
    # Create active employment for the person
    create(:employment_tenure, teammate: person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  describe 'GET /people/:id/public' do
    context 'when user is unauthenticated' do
      it 'allows access' do
        get public_person_path(person)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is authenticated from same organization' do
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: organization) }

      before do
        create(:employment_tenure, teammate: viewer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        sign_in_as_teammate_for_request(viewer, organization)
      end

      it 'allows access' do
        get public_person_path(person)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is authenticated from different organization' do
      let(:viewer) { create(:person) }
      let(:viewer_teammate) { create(:teammate, person: viewer, organization: other_organization) }

      before do
        create(:employment_tenure, teammate: viewer_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
        sign_in_as_teammate_for_request(viewer, other_organization)
      end

      it 'allows access' do
        get public_person_path(person)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when person has no teammates' do
      let(:person_without_teammates) { create(:person) }

      it 'allows access' do
        get public_person_path(person_without_teammates)
        expect(response).to have_http_status(:success)
      end
    end
  end
end

