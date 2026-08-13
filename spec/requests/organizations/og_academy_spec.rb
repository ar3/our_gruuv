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
    it 'returns success and renders the shell with lazy frames' do
      get organization_og_academy_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('OG Academy')
      expect(response.body).to include('Quick Start')
      expect(response.body).to include('OG Mastery milestones')
      expect(response.body).to include('Choose your home base')
      expect(response.body).to include('Learn OurGruuv by doing... quick start now...')
      expect(response.body).to include('Welcome to OG Academy')
      expect(response.body).to include('continuous clarity and unfading growth')
      expect(response.body).to include('Goal of this page')
      expect(response.body).to include('My Growth · Experiences')
      expect(response.body).to include('Celebrate Milestones')
      expect(response.body).to include('context-callout')
      expect(response.body).not_to include('coming soon')
      expect(response.body).to include(organization_og_academy_quick_start_path(company))
      expect(response.body).to include(organization_og_academy_milestones_path(company))
      expect(response.body).to include('Loading Quick Start')
      expect(response.body).to include('Loading OG Mastery milestones')
      expect(response.body).to include('target="_top"')
      expect(response.body).not_to include('turbo-cache-control')
    end
  end

  describe 'GET /organizations/:organization_id/og_academy/quick_start' do
    it 'includes the viewer and action links' do
      get organization_og_academy_quick_start_path(company), headers: { 'Turbo-Frame' => 'og_academy_quick_start' }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(person.casual_name)
      expect(response.body).to include('rounded-circle')
      expect(response.body).to include('Check-in')
      expect(response.body).to include('Observe')
      expect(response.body).to include('Goals')
      expect(response.body).to include('OGO')
      expect(response.body).to include('active and healthy')
      expect(response.body).to include(up_next_organization_company_teammate_check_ins_path(company, teammate))
      expect(response.body).to include(my_growth_goals_organization_company_teammate_path(company, teammate))
      expect(response.body).to include(ogos_organization_company_teammate_path(company, teammate))
      ogo_path = ogos_organization_company_teammate_path(company, teammate)
      growth_path = my_growth_goals_organization_company_teammate_path(company, teammate)
      up_next_path = up_next_organization_company_teammate_check_ins_path(company, teammate)
      expect(response.body.index(ogo_path)).to be < response.body.index(growth_path)
      expect(response.body.index(growth_path)).to be < response.body.index(up_next_path)
      expect(response.body).to include('target="_top"')
    end
  end

  describe 'GET /organizations/:organization_id/og_academy/milestones' do
    it 'links incomplete criteria that have a destination and tooltips the rest' do
      get organization_og_academy_milestones_path(company), headers: { 'Turbo-Frame' => 'og_academy_milestones' }
      body = response.body
      expect(body).to include(select_type_organization_observations_path(company))
      expect(body).to include(new_organization_goal_path(company, owner_id: "CompanyTeammate_#{teammate.id}"))
      expect(body).to include(organization_company_teammate_notifications_path(company, teammate))
      expect(body).to include('bi-question-circle')
      expect(body).to include('Have a manager certify a milestone on a company Ability.')
      expect(body).to include('data-bs-toggle="tooltip"')
    end

    it 'shows all five milestone accordion titles without an admin fold' do
      get organization_og_academy_milestones_path(company), headers: { 'Turbo-Frame' => 'og_academy_milestones' }
      expect(response.body).to include('OG Mastery @ Milestone 1')
      expect(response.body).to include('OG Mastery @ Milestone 2')
      expect(response.body).to include('OG Mastery @ Milestone 3')
      expect(response.body).to include('OG Mastery @ Milestone 4')
      expect(response.body).to include('OG Mastery @ Milestone 5')
      expect(response.body).not_to include('Admin & cross-company levels')
    end

    it 'renders practice certificate chrome for milestones' do
      get organization_og_academy_milestones_path(company), headers: { 'Turbo-Frame' => 'og_academy_milestones' }
      expect(response.body).to include('og-academy-certificate')
      expect(response.body).to include('Practice certification in progress')
      expect(response.body).to include('requirements sealed')
      expect(response.body).not_to include('Certified so far')
      expect(response.body).to include('data-bs-toggle="popover"')
      expect(response.body).to include('Why it matters:')
      expect(response.body).to include('am observing')
      expect(response.body).to include('to see them demonstrate OG Mastery so that I can...')
      expect(response.body).to include('border-warning')
      expect(response.body).not_to include('AM OBSERVING')
      expect(response.body).to include('Practice track')
      expect(response.body).to include('target="_top"')
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
