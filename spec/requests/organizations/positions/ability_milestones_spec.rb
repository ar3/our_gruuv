# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Position Direct Milestone Requirements', type: :request do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, person: person, organization: company, can_manage_maap: true) }
  let(:title) { create(:title, company: company) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let!(:ability1) { create(:ability, company: company) }

  before do
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/positions/:position_id/ability_milestones' do
    it 'returns success and renders the show page' do
      get organization_position_ability_milestones_path(company, position)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Direct Milestone Requirements')
      expect(response.body).to include(position.display_name)
    end

    it 'shows the view switcher with Direct Milestone Requirements as active when on this page' do
      get organization_position_ability_milestones_path(company, position)

      expect(response.body).to include('Direct Milestone Requirements (Active)')
    end
  end

  describe 'PATCH /organizations/:organization_id/positions/:position_id/ability_milestones' do
    it 'updates position ability milestones and redirects to position show' do
      patch organization_position_ability_milestones_path(company, position), params: {
        position_ability_milestones_form: {
          ability_milestones: { ability1.id.to_s => '3' }
        }
      }

      expect(response).to redirect_to(organization_position_path(company, position))
      expect(flash[:notice]).to be_present
      expect(position.position_abilities.find_by(ability: ability1).milestone_level).to eq(3)
    end
  end
end
