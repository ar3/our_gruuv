# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::PositionMajorLevels', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:major) { create(:position_major_level, set_name: 'Base 10x3', major_level: 2, description: 'Solid contributor') }
  let!(:level_1) { create(:position_level, position_major_level: major, level: '2.1') }
  let!(:level_2) { create(:position_level, position_major_level: major, level: '2.2') }
  let!(:title) { create(:title, company: organization, position_major_level: major, external_title: 'Analyst') }

  before do
    create(:teammate, person: person, organization: organization)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/position_major_levels/:id' do
    it 'lists position levels and titles for the major level' do
      get organization_position_major_level_path(organization, major)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('L:2.*')
      expect(response.body).to include('Base 10x3')
      expect(response.body).to include('Solid contributor')
      expect(response.body).to include('2.1')
      expect(response.body).to include('2.2')
      expect(response.body).to include('Analyst')
      expect(response.body).to include(organization_title_path(organization, title))
    end
  end
end
