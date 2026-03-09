require 'rails_helper'

RSpec.describe Organizations::CheckInsHealthController, type: :controller do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil, can_manage_employment: true)
  end

  before do
    teammate
    sign_in_as_teammate(person, company)
  end

  describe 'GET #index' do
    context 'when user has manage_employment' do
      it 'returns success' do
        get :index, params: { organization_id: company.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns employee_health_data, spotlight_stats, and filter options' do
        get :index, params: { organization_id: company.id }
        expect(assigns(:employee_health_data)).to be_an(Array)
        expect(assigns(:spotlight_stats)).to be_a(Hash)
        expect(assigns(:current_manager_filter)).to be_present
        expect(assigns(:available_manager_filter_options)).to be_an(Array)
      end

      it 'defaults manager filter to everyone' do
        get :index, params: { organization_id: company.id }
        expect(assigns(:current_manager_filter)).to eq('everyone')
      end
    end

    context 'when user does not have manage_employment' do
      before do
        teammate.update!(can_manage_employment: false)
      end

      it 'returns success (view-only)' do
        get :index, params: { organization_id: company.id }
        expect(response).to have_http_status(:success)
      end

      it 'defaults to just_me and restricts list to self' do
        get :index, params: { organization_id: company.id }
        expect(assigns(:current_manager_filter)).to eq('just_me')
        expect(assigns(:employee_health_data).map { |d| d[:teammate].id }).to contain_exactly(teammate.id)
      end
    end

    context 'with manager_id filter just_me' do
      it 'returns only current teammate' do
        get :index, params: { organization_id: company.id, manager_id: 'just_me' }
        expect(response).to have_http_status(:success)
        expect(assigns(:employee_health_data).map { |d| d[:teammate].id }).to contain_exactly(teammate.id)
      end
    end

    context 'when user is not employed' do
      before do
        teammate.update!(first_employed_at: nil, last_terminated_at: nil)
      end

      it 'redirects with authorization error' do
        get :index, params: { organization_id: company.id }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'GET #export' do
    it 'authorizes with check_ins_health? and returns CSV' do
      get :export, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')
    end

    it 'generates CSV with expected check-in headers' do
      get :export, params: { organization_id: company.id }
      csv = CSV.parse(response.body, headers: true)
      expect(csv.headers).to include(
        'Teammate Name',
        'Teammate Email',
        'Teammate Manager Name',
        'Teammate Manager Email',
        'Check-in Object',
        'Check-in Started',
        'Check-in Finalized',
        'Check-ins Finalized Before this',
        'Manager Check-in Completed At',
        'Manager who completed Check-in',
        'Employee Check-in Completed At',
        'Rating',
        'Shared Notes',
        'Employee Rating',
        'Employee Notes',
        'Manager Rating',
        'Manager Notes',
        'Expected Energy Percentage',
        'Actual Energy Percentage',
        'Employee Personal Alignment'
      )
    end

    context 'when user does not have check_ins_health access' do
      before do
        teammate.update!(first_employed_at: nil, last_terminated_at: nil)
      end

      it 'redirects with authorization error' do
        get :export, params: { organization_id: company.id }
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
