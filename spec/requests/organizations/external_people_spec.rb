# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::ExternalPeople', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:viewer) { create(:person) }
  let!(:viewer_teammate) { create(:company_teammate, person: viewer, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, organization: organization) }
  let(:external_person) { create(:person, first_name: 'Pat', last_name: 'External') }

  before do
    sign_in_as_teammate_for_request(viewer, organization)
  end

  describe 'GET /organizations/:organization_id/external_people/:id' do
    it 'shows an external person and OGOs visible to the viewer' do
      observation = build(:observation,
        company: organization,
        observer: external_person,
        privacy_level: :public_to_company,
        published_at: Time.current,
        story: 'Visible external OGO story'
      )
      observation.observees = []
      observation.observees.build(teammate: subject_teammate)
      observation.save!

      get organization_external_person_path(organization, external_person)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Pat')
      expect(response.body).to include('External')
      expect(response.body).to include('Not a teammate')
      expect(response.body).to include('Visible external OGO story')
      expect(response.body).to include(organization_observation_path(organization, observation))
    end

    it 'does not show OGOs the viewer cannot see' do
      private_obs = build(:observation,
        company: organization,
        observer: external_person,
        privacy_level: :observed_only,
        published_at: Time.current,
        story: 'Private to subject only'
      )
      private_obs.observees = []
      private_obs.observees.build(teammate: subject_teammate)
      private_obs.save!

      get organization_external_person_path(organization, external_person)
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('Private to subject only')
    end

    it 'redirects to the teammate profile when the person is actually a teammate' do
      get organization_external_person_path(organization, viewer)
      expect(response).to redirect_to(organization_company_teammate_path(organization, viewer_teammate))
    end

    it 'requires authentication' do
      sign_out_teammate_for_request
      get organization_external_person_path(organization, external_person)
      expect(response).to redirect_to(login_path)
    end
  end
end
