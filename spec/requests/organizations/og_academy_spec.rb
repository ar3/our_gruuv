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

    it 'renders the Explore button row between Quick Start and OG Mastery' do
      get organization_og_academy_path(company)
      expect(response).to have_http_status(:success)
      body = response.body
      expect(body).to include('Explore:')
      expect(body).to include(celebrate_milestones_organization_path(company))
      expect(body).to include(organization_abilities_path(company))
      expect(body).to include(organization_assignments_path(company))
      expect(body).to include(organization_positions_path(company))
      expect(body).to include('>M</span>')
      expect(body).to include('>ilestones</span>')
      expect(body).to include('>A</span>')
      expect(body).to include('>bilities</span>')
      expect(body).to include('>ssignments</span>')
      expect(body).to include('>P</span>')
      expect(body).to include('>ositions</span>')
      expect(body.index('Explore:')).to be > body.index('og_academy_quick_start')
      expect(body.index('Explore:')).to be < body.index('og-academy-milestones')
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

    it 'replaces My One Thing with an expandable teammate views list' do
      get organization_og_academy_quick_start_path(company), headers: { 'Turbo-Frame' => 'og_academy_quick_start' }
      expect(response).to have_http_status(:success)
      expect(response.body).to include('show all of my links...')
      expect(response.body).to include("Views for #{person.casual_name}")
      expect(response.body).to include('ogAcademyTeammateLinks')
      expect(response.body).to include('data-bs-toggle="collapse"')
      expect(response.body).to include('internal-teammate-views-nav')
      expect(response.body).to include('1:1, about &amp; growth')
      expect(response.body).to include(organization_company_teammate_one_on_one_link_path(company, teammate))
      expect(response.body).not_to include('internal-teammate-views-nav__expand-prompt')
    end

    it "labels a direct report expand control with their casual name" do
      report_person = create(:person, first_name: 'Jamie', last_name: 'Report')
      report = create(:teammate, person: report_person, organization: company)
      create(:employment_tenure, teammate: report, company: company, manager_teammate: teammate)

      get organization_og_academy_quick_start_path(company), headers: { 'Turbo-Frame' => 'og_academy_quick_start' }
      expect(response).to have_http_status(:success)
      body = CGI.unescapeHTML(response.body)
      expect(body).to include("show all of #{report_person.casual_name}'s links...")
      expect(body).to include("Views for #{report_person.casual_name}")
    end
  end

  describe 'GET /organizations/:organization_id/og_academy/milestones' do
    it 'links incomplete criteria that have a destination and tooltips the rest' do
      get organization_og_academy_milestones_path(company), headers: { 'Turbo-Frame' => 'og_academy_milestones' }
      body = response.body
      expect(body).to include(select_type_organization_observations_path(company))
      expect(body).to include(select_create_organization_goals_path(company, for_company_teammate_id: teammate.id))
      expect(body).to include(organization_company_teammate_notifications_path(company, teammate))
      expect(body).to include(new_organization_feedback_request_path(company))
      expect(body).to include(ogos_feedback_requests_organization_company_teammate_path(company, "me"))
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
