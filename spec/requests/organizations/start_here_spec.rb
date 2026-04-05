# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::StartHere', type: :request do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/start_here' do
    it 'returns http success' do
      get organization_start_here_path(company)
      expect(response).to have_http_status(:success)
    end

    it 'renders Start Here with title and manager-default widgets' do
      get organization_start_here_path(company)
      expect(response.body).to include('Start Here')
      expect(response.body).to include('quick guide')
      expect(response.body).to include('About')
      expect(response.body).to include('TODOs')
      expect(response.body).to include('Kudos')
      expect(response.body).to include('Insights')
      expect(response.body).to include('start-here-dashboard-skeleton')
    end

    it 'uses org label for get_shit_done when set' do
      create(:company_label_preference, company: company, label_key: 'get_shit_done', label_value: 'Action Items')
      get organization_start_here_path(company)
      expect(response.body).to include('Action Items')
    end

    it 'includes on-page layout controls' do
      get organization_start_here_path(company)
      expect(response.body).to include('Manager default')
      expect(response.body).to include('Add new widgets')
    end

    it 'shows Other ways to customize section with navigation and digest controls' do
      get organization_start_here_path(company)
      expect(response.body).to include('Other ways to customize OurGruuv')
      expect(response.body).to include('Navigation style')
      expect(response.body).to include('Send me the OG digest')
      expect(response.body).to include('Clean/No Navigation')
    end

    it 'shows start page picker when layout is vertical or horizontal' do
      get organization_start_here_path(company)
      expect(response.body).to include('Start page when I open')
    end

    it 'does not show start page picker when layout is no_nav' do
      UserPreference.for_person(person).update_preference(:layout, 'no_nav')
      get organization_start_here_path(company)
      expect(response.body).not_to include('id="start_here_start_page"')
    end

    it 'normalizes start page to Start Here when layout is no_nav' do
      key = "start_page_#{company.id}"
      UserPreference.for_person(person).update_preference(:layout, 'no_nav')
      UserPreference.for_person(person).update_preference(key, 'insights')
      get organization_start_here_path(company)
      expect(UserPreference.for_person(person).reload.preference(key)).to eq('start_here')
    end
  end

  describe 'POST /organizations/:organization_id/start_here/widget_dashboards' do
    it 'returns JSON with html for widgets on the user dashboard' do
      post organization_start_here_widget_dashboards_path(company),
           params: { widget_ids: %w[about_me get_shit_done] },
           as: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['widgets']['about_me']['ok']).to eq(true)
      expect(json['widgets']['about_me']['html']).to be_present
      expect(json['widgets']['about_me']['html']).to include('Your check-ins, goals, observations, and growth in one place.')
      expect(json['widgets']['get_shit_done']['ok']).to eq(true)
    end

    it 'omits widget ids that are not on the user dashboard' do
      post organization_start_here_widget_dashboards_path(company),
           params: { widget_ids: %w[about_me not_on_my_dashboard_xyz] },
           as: :json
      json = JSON.parse(response.body)
      expect(json['widgets'].keys).to eq([ 'about_me' ])
    end
  end

  describe 'POST /organizations/:organization_id/start_here/update_start_page' do
    it 'updates start page and redirects' do
      post organization_start_here_update_start_page_path(company), params: { start_page: 'insights' }
      expect(response).to redirect_to(organization_start_here_path(company))
      key = "start_page_#{company.id}"
      expect(UserPreference.for_person(person).reload.preference(key)).to eq('insights')
    end

    it 'rejects invalid start page value' do
      post organization_start_here_update_start_page_path(company), params: { start_page: 'not_a_real_page' }
      expect(response).to redirect_to(organization_start_here_path(company))
      expect(flash[:alert]).to match(/Invalid start page/)
    end
  end

  describe 'POST /organizations/:organization_id/start_here/remove_widget' do
    it 'removes a widget and redirects' do
      post organization_start_here_remove_widget_path(company), params: { widget_id: 'get_shit_done' }
      expect(response).to redirect_to(organization_start_here_path(company))
    end
  end

  describe 'POST /organizations/:organization_id/start_here/add_widget' do
    it 'accepts add for a valid widget id' do
      post organization_start_here_remove_widget_path(company), params: { widget_id: 'get_shit_done' }
      post organization_start_here_add_widget_path(company), params: { widget_id: 'get_shit_done' }
      expect(response).to redirect_to(organization_start_here_path(company))
    end
  end

  describe 'POST /organizations/:organization_id/start_here/reorder_widget' do
    it 'redirects after reorder' do
      post organization_start_here_reorder_widget_path(company), params: { widget_id: 'about_me', position: 2 }
      expect(response).to redirect_to(organization_start_here_path(company))
    end
  end

  describe 'POST /organizations/:organization_id/start_here/apply_preset' do
    it 'applies non_manager preset' do
      post organization_start_here_apply_preset_path(company), params: { preset: 'non_manager' }
      expect(response).to redirect_to(organization_start_here_path(company))
    end
  end
end
