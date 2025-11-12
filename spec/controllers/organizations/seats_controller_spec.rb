require 'rails_helper'

RSpec.describe Organizations::SeatsController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:person_teammate) { create(:teammate, person: person, organization: company) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:seat) { create(:seat, position_type: position_type, seat_needed_by: Date.current) }

  before do
    session[:current_company_teammate_id] = person_teammate.id
    @current_company_teammate = nil if defined?(@current_company_teammate)
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'calculates spotlight stats for employees' do
      employee1 = create(:person)
      employee2 = create(:person)
      employee1_teammate = create(:teammate, person: employee1, organization: company, first_employed_at: 1.year.ago)
      employee2_teammate = create(:teammate, person: employee2, organization: company, first_employed_at: 6.months.ago)
      
      tenure1 = create(:employment_tenure, teammate: employee1_teammate, company: company, position: position, started_at: 1.year.ago, seat: seat)
      tenure2 = create(:employment_tenure, teammate: employee2_teammate, company: company, position: position, started_at: 6.months.ago, seat: nil)
      
      get :index, params: { organization_id: company.id }
      
      stats = assigns(:spotlight_stats)
      expect(stats[:employees][:total]).to eq(2)
      expect(stats[:employees][:with_seats]).to eq(1)
      expect(stats[:employees][:without_seats]).to eq(1)
    end

    it 'calculates spotlight stats for position types' do
      position_type2 = create(:position_type, organization: company, position_major_level: position_major_level)
      create(:seat, position_type: position_type, seat_needed_by: Date.current)
      # position_type2 has no seats
      
      get :index, params: { organization_id: company.id }
      
      stats = assigns(:spotlight_stats)
      expect(stats[:position_types][:total]).to eq(2)
      expect(stats[:position_types][:with_seats]).to eq(1)
      expect(stats[:position_types][:without_seats]).to eq(1)
    end
  end

  describe 'POST #create_missing_employee_seats' do
    context 'with MAAP management permission' do
      before do
        person_teammate.update!(can_manage_maap: true)
      end

      it 'creates seats for employees without seats' do
        employee1 = create(:person)
        employee1_teammate = create(:teammate, person: employee1, organization: company, first_employed_at: 1.year.ago)
        tenure = create(:employment_tenure, teammate: employee1_teammate, company: company, position: position, started_at: 1.year.ago, seat: nil)
        
        expect {
          post :create_missing_employee_seats, params: { organization_id: company.id }
        }.to change { Seat.count }.by(1)
          .and change { tenure.reload.seat_id }.from(nil)
        
        expect(response).to redirect_to(organization_seats_path(company))
        expect(flash[:notice]).to include('Successfully created')
      end

      it 'associates multiple tenures with the same seat when they share position type and date' do
        employee1 = create(:person)
        employee2 = create(:person)
        employee1_teammate = create(:teammate, person: employee1, organization: company, first_employed_at: 1.year.ago)
        employee2_teammate = create(:teammate, person: employee2, organization: company, first_employed_at: 1.year.ago)
        
        start_date = 1.year.ago.to_date
        tenure1 = create(:employment_tenure, teammate: employee1_teammate, company: company, position: position, started_at: start_date, seat: nil)
        tenure2 = create(:employment_tenure, teammate: employee2_teammate, company: company, position: position, started_at: start_date, seat: nil)
        
        expect {
          post :create_missing_employee_seats, params: { organization_id: company.id }
        }.to change { Seat.count }.by(1)
          .and change { tenure1.reload.seat_id }.from(nil)
          .and change { tenure2.reload.seat_id }.from(nil)
        
        tenure1.reload
        tenure2.reload
        expect(tenure1.seat_id).to eq(tenure2.seat_id)
        expect(tenure1.seat).to be_present
        expect(flash[:notice]).to include('2 seat(s)') # Two associations
      end
    end

    context 'without MAAP management permission' do
      it 'redirects with error' do
        post :create_missing_employee_seats, params: { organization_id: company.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #create_missing_position_type_seats' do
    context 'with MAAP management permission' do
      before do
        person_teammate.update!(can_manage_maap: true)
      end

      it 'creates seats for position types without seats' do
        position_type2 = create(:position_type, organization: company, position_major_level: position_major_level)
        
        expect {
          post :create_missing_position_type_seats, params: { organization_id: company.id }
        }.to change { Seat.count }.by(1)
        
        expect(Seat.last.position_type).to eq(position_type2)
        expect(Seat.last.state).to eq('draft')
        expect(response).to redirect_to(organization_seats_path(company))
        expect(flash[:notice]).to include('Successfully created')
      end

      it 'skips position types that already have seats' do
        create(:seat, position_type: position_type, seat_needed_by: Date.current)
        
        expect {
          post :create_missing_position_type_seats, params: { organization_id: company.id }
        }.not_to change { Seat.count }
      end
    end

    context 'without MAAP management permission' do
      it 'redirects with error' do
        post :create_missing_position_type_seats, params: { organization_id: company.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end

