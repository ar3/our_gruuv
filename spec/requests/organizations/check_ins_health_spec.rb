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
      expect(response.body).to include('checkInsHealthPageInfo')
      expect(response.body).to include('Ultimate goal')
      expect(response.body).to include('Top bar (Gruuv Health Required Clarity)')
      expect(response.body).to include('Bottom bar (action-based)')
      expect(response.body).to include('Gruuv Health Required Clarity')
      expect(response.body).to include('Who to show')
      expect(response.body).to include('Aspirations')
      expect(response.body).to include('Assignments')
      expect(response.body).to include('Position')
      expect(response.body).not_to include('>Milestones<')
    end

    it "shows health dashboard switcher with links to goals and observations health" do
      get organization_check_ins_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(organization_goals_health_path(company, manager_id: "everyone"))
      expect(response.body).to include(organization_observations_health_path(company, manager_id: "everyone"))
      expect(response.body).to include('aria-label="Health dashboards"')
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

    it 'shows secondary Gruuv Health alert and refresh control when engagement health exists' do
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: company,
        level: 'item',
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        entity_type: 'Assignment',
        entity_id: 456,
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: {
          'name' => 'Task',
          'action_bar_color' => 'red',
          'open_check_in_present' => false
        },
        computed_at: Time.current
      )
      EngagementHealthStatus.create!(
        teammate: teammate,
        organization: company,
        level: 'category',
        category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
        status: EngagementHealth::NEEDS_ATTENTION,
        inputs: { 'item_count' => 1 },
        computed_at: Time.current
      )

      get organization_check_ins_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Consider checking in on:')
      expect(response.body).to include('bi-arrow-clockwise')
      expect(response.body).to include('% ok')
      expect(response.body).to include('clarity-action-slots-summary')
      expect(response.body).to include('actions to get to full MAAP Check-in clarity health')
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

    it 'enqueues a Gruuv Health refresh job for the teammate' do
      expect do
        post organization_check_ins_health_refresh_path(company), params: { teammate_id: teammate.id }
      end.to have_enqueued_job(EngagementHealthRefreshJob).with(teammate.id)

      job_classes = enqueued_jobs.map { |job| job[:job] }
      expect(job_classes).to include(EngagementHealthRefreshJob)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(organization_check_ins_health_path(company))
    end
  end

  describe 'POST /organizations/:organization_id/check_ins_health_refresh_all' do
    include ActiveJob::TestHelper

    it 'enqueues Gruuv Health refresh jobs for the current filtered teammates' do
      expect do
        post organization_check_ins_health_refresh_all_path(company), params: { manager_id: 'just_me' }
      end.to have_enqueued_job(EngagementHealthRefreshJob).with(teammate.id)

      job_classes = enqueued_jobs.map { |job| job[:job] }
      expect(job_classes).to include(EngagementHealthRefreshJob)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(organization_check_ins_health_path(company, manager_id: 'just_me'))
    end
  end
end
