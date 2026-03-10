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

    it 'with manager_id=just_me returns success' do
      get organization_check_ins_health_path(company), params: { manager_id: 'just_me' }
      expect(response).to have_http_status(:success)
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

  describe 'GET /organizations/:organization_id/check_ins_health_by_manager' do
    context 'when user has manage_employment' do
      it 'returns success and shows by manager content' do
        get organization_check_ins_health_by_manager_path(company)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Check-ins Health by Manager')
        expect(response.body).to include('Manager')
        expect(response.body).to include('Aspirations')
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
end
