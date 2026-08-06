# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::OgAcademy', type: :request do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/og_academy' do
    it 'returns success and renders core sections' do
      get organization_og_academy_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('OG Academy')
      expect(response.body).to include('Quick Start')
      expect(response.body).to include('Earn your OG Academy milestones')
      expect(response.body).to include('Practice track')
      expect(response.body).to include('Choose your home base')
      expect(response.body).to include('Check-in')
      expect(response.body).to include('Observe')
      expect(response.body).to include('Goal confidence')
    end

    it 'includes the viewer in Quick Start' do
      get organization_og_academy_path(company)
      expect(response.body).to include(person.casual_name)
    end

    it 'collapses manager/admin levels when the viewer has no reports' do
      get organization_og_academy_path(company)
      expect(response.body).to include('Manager & admin levels (M3+)')
    end
  end

  describe 'POST /organizations/:organization_id/og_academy/update_start_page' do
    it 'updates the start page preference and redirects to the chosen path' do
      post organization_og_academy_update_start_page_path(company), params: { start_page: 'start_here' }
      expect(response).to redirect_to(organization_start_here_path(company))
      expect(UserPreference.for_person(person).preference("start_page_#{company.id}")).to eq('start_here')
    end
  end
end
