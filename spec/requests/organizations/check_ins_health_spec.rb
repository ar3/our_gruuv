# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Check-ins Health', type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil, can_manage_employment: true)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/check_ins_health' do
    it 'returns success and shows filter and table' do
      get organization_check_ins_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Check-ins Health')
      expect(response.body).to include('Who to show')
      expect(response.body).to include('Aspirations')
      expect(response.body).to include('Assignments')
      expect(response.body).to include('Position')
      expect(response.body).to include('Milestones')
    end

    it 'shows By manager link when user can view by manager' do
      get organization_check_ins_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('By manager')
      expect(response.body).to include(organization_check_ins_health_by_manager_path(company))
    end

    it 'shows employee summary CSV download button' do
      get organization_check_ins_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Download employee check-in summary CSV')
      expect(response.body).to include(organization_check_ins_health_employee_summary_export_path(company))
    end

    it 'with manager_id=just_me returns success' do
      get organization_check_ins_health_path(company), params: { manager_id: 'just_me' }
      expect(response).to have_http_status(:success)
    end

    it 'shows secondary required clarity and refresh control when cache exists' do
      create(
        :check_in_health_cache,
        teammate: teammate,
        organization: company,
        refreshed_at: 1.hour.ago,
        payload: {
          'position' => { 'category' => 'green' },
          'assignments' => [],
          'aspirations' => [],
          'milestones' => { 'total_required' => 0, 'earned_count' => 0 },
          'required_check_ins' => {
            'position' => [ { 'type' => 'position', 'item_id' => 123, 'name' => 'Role', 'clarity_level' => 'clear', 'latest_finalized_rating' => 'meeting' } ],
            'assignments' => [ { 'type' => 'assignment', 'item_id' => 456, 'name' => 'Task', 'clarity_level' => 'obscured', 'latest_finalized_rating' => 'working_to_meet' } ],
            'aspirations' => []
          }
        }
      )

      get organization_check_ins_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Consider checking in on:')
      expect(response.body).to include('bi-arrow-clockwise')
    end
  end

  describe 'GET /organizations/:organization_id/check_ins_health_export' do
    it 'returns CSV attachment' do
      get organization_check_ins_health_export_path(company)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')
    end
  end

  describe 'GET /organizations/:organization_id/check_ins_health_employee_summary_export' do
    it 'returns CSV attachment' do
      get organization_check_ins_health_employee_summary_export_path(company)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')
    end
  end

  describe 'GET /organizations/:organization_id/check_ins_health_by_manager' do
    context 'when user has manage_employment' do
      it 'returns success and shows by manager content' do
        get organization_check_ins_health_by_manager_path(company)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Check-ins Health by Manager')
        expect(response.body).to include('Manager')
        # With manager rows: table with Aspirations header and sort toggle; without: empty state
        has_table = response.body.include?('Aspirations')
        has_empty_state = response.body.include?('No managers with direct reports')
        expect(has_table || has_empty_state).to be true
      end
    end

    context 'when user is not a manager and does not have manage_employment' do
      before do
        teammate.update!(can_manage_employment: false)
        teammate.reload
        # Re-stub so current_company_teammate returns the updated teammate
        allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(teammate)
      end

      it 'redirects to check_ins_health with alert' do
        get organization_check_ins_health_by_manager_path(company)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_check_ins_health_path(company))
      end
    end
  end

  describe 'POST /organizations/:organization_id/check_ins_health_refresh' do
    include ActiveJob::TestHelper

    it 'enqueues a refresh job for the teammate' do
      expect do
        post organization_check_ins_health_refresh_path(company), params: { teammate_id: teammate.id }
      end.to have_enqueued_job(CheckInHealthCacheRefreshJob).with(teammate.id)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(organization_check_ins_health_path(company))
    end
  end

  describe 'POST /organizations/:organization_id/check_ins_health_refresh_all' do
    include ActiveJob::TestHelper

    it 'enqueues refresh jobs for the current filtered teammates' do
      expect do
        post organization_check_ins_health_refresh_all_path(company), params: { manager_id: 'just_me' }
      end.to have_enqueued_job(CheckInHealthCacheRefreshJob).with(teammate.id)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(organization_check_ins_health_path(company, manager_id: 'just_me'))
    end
  end
end
