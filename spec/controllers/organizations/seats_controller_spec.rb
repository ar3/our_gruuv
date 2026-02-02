require 'rails_helper'

RSpec.describe Organizations::SeatsController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization) }
  let(:person_teammate) { create(:teammate, person: person, organization: company, first_employed_at: 1.year.ago) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, title: title, position_level: position_level) }
  
  # Ensure title is consistent - reload position to get fresh title
  before do
    position.reload if position.persisted?
  end
  let(:seat) { create(:seat, title: title, seat_needed_by: Date.current) }

  before do
    person_teammate.update!(can_manage_maap: true) # Ensure MAAP access for all tests
    session[:current_company_teammate_id] = person_teammate.id
    @current_company_teammate = nil if defined?(@current_company_teammate)
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'uses default table view' do
      # Ensure seat exists and is accessible
      seat # trigger creation
      
      get :index, params: { organization_id: company.id }
      expect(assigns(:current_view)).to eq('table')
      expect(assigns(:filtered_seats)).to be_present
      expect(assigns(:filtered_seats)).to include(seat)
    end

    it 'filters by state' do
      create(:seat, :open, title: title, seat_needed_by: Date.current + 1.month)
      create(:seat, :filled, title: title, seat_needed_by: Date.current + 2.months)
      
      get :index, params: { organization_id: company.id, state: ['open'] }
      
      filtered_seats = assigns(:filtered_seats)
      expect(filtered_seats.all? { |s| s.state == 'open' }).to be true
    end

    it 'filters by has_direct_reports' do
      parent_seat = create(:seat, title: title, seat_needed_by: Date.current + 1.month)
      create(:seat, title: title, seat_needed_by: Date.current + 2.months, reports_to_seat: parent_seat)
      childless_seat = create(:seat, title: title, seat_needed_by: Date.current + 3.months)
      
      get :index, params: { organization_id: company.id, has_direct_reports: 'true' }
      
      filtered_seats = assigns(:filtered_seats)
      expect(filtered_seats).to include(parent_seat)
      expect(filtered_seats).not_to include(childless_seat)
    end

    it 'handles seat_hierarchy view' do
      parent_seat = create(:seat, title: title, seat_needed_by: Date.current + 1.month)
      create(:seat, title: title, seat_needed_by: Date.current + 2.months, reports_to_seat: parent_seat)
      
      get :index, params: { organization_id: company.id, view: 'seat_hierarchy' }
      
      expect(assigns(:current_view)).to eq('seat_hierarchy')
      expect(assigns(:hierarchy_tree)).to be_present
    end

    it 'handles seat_maap_health view' do
      create(:seat, title: title, seat_needed_by: Date.current)
      
      get :index, params: { organization_id: company.id, view: 'seat_maap_health' }
      
      expect(assigns(:current_view)).to eq('seat_maap_health')
      expect(assigns(:seats_by_title)).to be_present
      expect(assigns(:titles)).to be_present
    end

    it 'handles table_with_employee view' do
      employee = create(:person)
      employee_teammate = create(:teammate, person: employee, organization: company, first_employed_at: 1.year.ago)
      # Create tenure first, then create seat with matching title_id
      tenure = create(:employment_tenure, teammate: employee_teammate, company: company, position: position, started_at: 1.year.ago, seat: nil)
      # Reload position to get fresh title_id
      tenure.position.reload
      seat_with_employee = create(:seat, :filled, title_id: tenure.position.title_id, seat_needed_by: Date.current)
      tenure.update!(seat: seat_with_employee)
      
      get :index, params: { organization_id: company.id, view: 'table_with_employee' }
      
      expect(assigns(:current_view)).to eq('table_with_employee')
      expect(assigns(:filtered_seats)).to be_present
      expect(assigns(:filtered_seats)).to include(seat_with_employee)
    end

    it 'groups seats by department for table view' do
      dept_a = create(:department, company: company, name: 'Department A')
      dept_b = create(:department, company: company, name: 'Department B')
      
      title_a = create(:title, company: company, department: dept_a, position_major_level: position_major_level, external_title: 'Title A')
      title_b = create(:title, company: company, department: dept_b, position_major_level: position_major_level, external_title: 'Title B')
      title_no_dept = create(:title, company: company, department: nil, position_major_level: position_major_level, external_title: 'Title No Dept')
      
      seat_a = create(:seat, title: title_a, seat_needed_by: Date.current)
      seat_b = create(:seat, title: title_b, seat_needed_by: Date.current + 1.month)
      seat_no_dept = create(:seat, title: title_no_dept, seat_needed_by: Date.current + 2.months)
      
      get :index, params: { organization_id: company.id, view: 'table' }
      
      expect(assigns(:current_view)).to eq('table')
      expect(assigns(:seats_by_department)).to be_present
      
      # Find departments by ID since they might be different object instances
      dept_a_key = assigns(:seats_by_department).keys.find { |k| k&.id == dept_a.id }
      dept_b_key = assigns(:seats_by_department).keys.find { |k| k&.id == dept_b.id }
      
      expect(dept_a_key).not_to be_nil
      expect(dept_b_key).not_to be_nil
      expect(assigns(:seats_by_department).keys).to include(nil)
      expect(assigns(:seats_by_department)[dept_a_key]).to include(seat_a)
      expect(assigns(:seats_by_department)[dept_b_key]).to include(seat_b)
      expect(assigns(:seats_by_department)[nil]).to include(seat_no_dept)
    end

    it 'sorts departments hierarchically' do
      dept_a = create(:department, company: company, name: 'Department A')
      dept_a1 = create(:department, company: company, parent_department: dept_a, name: 'Department A.1')
      dept_b = create(:department, company: company, name: 'Department B')
      
      title_a = create(:title, company: company, department: dept_a, position_major_level: position_major_level, external_title: 'Title A')
      title_a1 = create(:title, company: company, department: dept_a1, position_major_level: position_major_level, external_title: 'Title A1')
      title_b = create(:title, company: company, department: dept_b, position_major_level: position_major_level, external_title: 'Title B')
      title_no_dept = create(:title, company: company, department: nil, position_major_level: position_major_level, external_title: 'Title No Dept')
      
      create(:seat, title: title_a, seat_needed_by: Date.current)
      create(:seat, title: title_a1, seat_needed_by: Date.current)
      create(:seat, title: title_b, seat_needed_by: Date.current)
      create(:seat, title: title_no_dept, seat_needed_by: Date.current)
      
      get :index, params: { organization_id: company.id, view: 'table' }
      
      seats_by_dept = assigns(:seats_by_department)
      dept_keys = seats_by_dept.keys
      
      # No department should come first
      expect(dept_keys.first).to be_nil
      
      # Then departments sorted hierarchically by display_name
      dept_names = dept_keys.compact.map(&:display_name)
      expect(dept_names).to eq([
        "Department A",
        "Department A > Department A.1",
        "Department B"
      ])
    end

    it 'sorts seats within each department by title then seat_needed_by' do
      dept = create(:department, company: company, name: 'Department A')
      
      title_z = create(:title, company: company, department: dept, position_major_level: position_major_level, external_title: 'Z Title')
      title_a = create(:title, company: company, department: dept, position_major_level: position_major_level, external_title: 'A Title')
      
      seat_z_later = create(:seat, title: title_z, seat_needed_by: Date.current + 2.months)
      seat_a_earlier = create(:seat, title: title_a, seat_needed_by: Date.current)
      seat_a_later = create(:seat, title: title_a, seat_needed_by: Date.current + 1.month)
      
      get :index, params: { organization_id: company.id, view: 'table' }
      
      seats_by_dept = assigns(:seats_by_department)
      # Find department by ID since it might be a different object instance
      dept_key = seats_by_dept.keys.find { |k| k&.id == dept.id }
      
      expect(dept_key).not_to be_nil
      seats_in_dept = seats_by_dept[dept_key]
      expect(seats_in_dept.map(&:id)).to eq([seat_a_earlier.id, seat_a_later.id, seat_z_later.id])
    end

    it 'calculates spotlight stats for employees' do
      employee1 = create(:person)
      employee2 = create(:person)
      employee1_teammate = create(:teammate, person: employee1, organization: company, first_employed_at: 1.year.ago)
      employee2_teammate = create(:teammate, person: employee2, organization: company, first_employed_at: 6.months.ago)
      
      # Create tenure first, then create seat with matching title
      tenure1 = create(:employment_tenure, teammate: employee1_teammate, company: company, position: position, started_at: 1.year.ago, seat: nil)
      # Reload position to get fresh title_id
      tenure1.position.reload
      seat_for_tenure = create(:seat, title_id: tenure1.position.title_id, seat_needed_by: 1.year.ago.to_date)
      tenure1.update!(seat: seat_for_tenure)
      tenure2 = create(:employment_tenure, teammate: employee2_teammate, company: company, position: position, started_at: 6.months.ago, seat: nil)
      
      get :index, params: { organization_id: company.id }
      
      stats = assigns(:spotlight_stats)
      expect(stats[:employees][:total]).to eq(2)
      expect(stats[:employees][:with_seats]).to eq(1)
      expect(stats[:employees][:without_seats]).to eq(1)
    end

    it 'calculates spotlight stats for position types' do
      title2 = create(:title, company: company, position_major_level: position_major_level, external_title: "Product Manager")
      create(:seat, title: title, seat_needed_by: Date.current)
      # title2 has no seats
      
      get :index, params: { organization_id: company.id }
      
      stats = assigns(:spotlight_stats)
      expect(stats[:titles][:total]).to eq(2)
      expect(stats[:titles][:with_seats]).to eq(1)
      expect(stats[:titles][:without_seats]).to eq(1)
    end
  end

  describe 'GET #customize_view' do
    it 'returns http success' do
      get :customize_view, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'loads current filters and view state' do
      get :customize_view, params: { organization_id: company.id, view: 'table_with_employee', state: ['open'] }
      
      expect(assigns(:current_view)).to eq('table_with_employee')
      expect(assigns(:current_filters)[:state]).to eq(['open'])
    end

    it 'sets return URL' do
      get :customize_view, params: { organization_id: company.id }
      expect(assigns(:return_url)).to include(organization_seats_path(company))
    end
  end

  describe 'PATCH #update_view' do
    it 'redirects with view params' do
      patch :update_view, params: { 
        organization_id: company.id, 
        view: 'table_with_employee',
        state: ['open', 'filled']
      }
      
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include(organization_seats_path(company).split('/').last)
      expect(response.location).to include('view=table_with_employee')
      expect(response.location).to include('state%5B%5D=open')
      expect(response.location).to include('state%5B%5D=filled')
    end

    it 'handles preset selection' do
      patch :update_view, params: { 
        organization_id: company.id, 
        preset: 'seat_hierarchy'
      }
      
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include(organization_seats_path(company).split('/').last)
      expect(response.location).to include('view=seat_hierarchy')
    end

    it 'shows success notice' do
      patch :update_view, params: { 
        organization_id: company.id, 
        view: 'table'
      }
      
      expect(flash[:notice]).to eq('View updated successfully.')
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
        # Ensure position is persisted
        position.save! unless position.persisted?
        
        # Build tenures without the factory's after_build hook creating new positions
        # The factory has an after_build that creates a position, so we need to build then assign
        tenure1 = build(:employment_tenure, teammate: employee1_teammate, company: company, started_at: start_date, seat: nil)
        tenure1.position = position
        tenure1.save!
        
        tenure2 = build(:employment_tenure, teammate: employee2_teammate, company: company, started_at: start_date, seat: nil)
        tenure2.position = position
        tenure2.save!
        
        # The service should create 1 seat and associate both tenures with it
        # created_count counts associations, not seats, so it will be 2
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
      before do
        person_teammate.update!(can_manage_maap: false)
      end

      it 'redirects with error' do
        post :create_missing_employee_seats, params: { organization_id: company.id }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'POST #create' do
    context 'with MAAP management permission' do
      before do
        person_teammate.update!(can_manage_maap: true)
      end

      let(:department) { create(:department, company: company) }
      let(:team) { create(:team, company: company) }

      it 'creates a seat with department, team, and reports_to_seat associations' do
        # Ensure department and team belong to company
        expect(department.company).to eq(company)
        expect(team.company).to eq(company)

        # Create reports_to_seat inside the test to avoid counting it in the expectation
        reports_to_seat = create(:seat, title: title, seat_needed_by: Date.current + 6.months)

        # Set department on title
        title.update!(department: department)

        expect {
          post :create, params: {
            organization_id: company.id,
            seat: {
              title_id: title.id,
              seat_needed_by: Date.current + 3.months,
              team_id: team.id,
              reports_to_seat_id: reports_to_seat.id
            }
          }
        }.to change { Seat.count }.by(1)

        created_seat = Seat.last
        expect(created_seat.title.department_id).to eq(department.id)
        expect(created_seat.department_id).to eq(department.id)
        expect(created_seat.team_id).to eq(team.id)
        expect(created_seat.reports_to_seat_id).to eq(reports_to_seat.id)
      end

      it 'creates a seat without associations' do
        expect {
          post :create, params: {
            organization_id: company.id,
            seat: {
              title_id: title.id,
              seat_needed_by: Date.current + 3.months
            }
          }
        }.to change { Seat.count }.by(1)

        created_seat = Seat.last
        expect(created_seat.department).to be_nil
        expect(created_seat.team).to be_nil
        expect(created_seat.reports_to_seat).to be_nil
      end
    end
  end

  describe 'PATCH #update' do
    context 'with MAAP management permission' do
      before do
        person_teammate.update!(can_manage_maap: true)
      end

      let(:department) { create(:department, company: company) }
      let(:team) { create(:team, company: company) }

      it 'updates a seat with team and reports_to_seat associations' do
        # Set department on title
        seat.title.update!(department: department)
        
        reports_to_seat = create(:seat, title: title, seat_needed_by: Date.current + 6.months)
        patch :update, params: {
          organization_id: company.id,
          id: seat.id,
          seat: {
            team_id: team.id,
            reports_to_seat_id: reports_to_seat.id
          }
        }

        seat.reload
        expect(seat.title.department_id).to eq(department.id)
        expect(seat.department_id).to eq(department.id)
        expect(seat.team_id).to eq(team.id)
        expect(seat.reports_to_seat_id).to eq(reports_to_seat.id)
      end

      it 'clears associations when set to empty string' do
        reports_to_seat = create(:seat, title: title, seat_needed_by: Date.current + 6.months)
        seat.title.update!(department: department)
        seat.update!(team: team, reports_to_seat: reports_to_seat)

        patch :update, params: {
          organization_id: company.id,
          id: seat.id,
          seat: {
            team_id: '',
            reports_to_seat_id: ''
          }
        }

        seat.reload
        expect(seat.team).to be_nil
        expect(seat.reports_to_seat).to be_nil
        # Department comes from title, so it should still be set
        expect(seat.department).to be_a(Department)
        expect(seat.department.id).to eq(department.id)
      end
    end
  end

  describe 'POST #create_missing_title_seats' do
    context 'with MAAP management permission' do
      before do
        person_teammate.update!(can_manage_maap: true)
      end

      it 'creates seats for position types without seats' do
        title2 = create(:title, company: company, position_major_level: position_major_level, external_title: "Product Manager")
        
        # Both title and title2 don't have seats, so 2 seats will be created
        expect {
          post :create_missing_title_seats, params: { organization_id: company.id }
        }.to change { Seat.count }.by(2)
        
        # Check that seats were created for both position types
        expect(Seat.where(title: title2).count).to eq(1)
        expect(Seat.where(title: title).count).to eq(1)
        expect(Seat.where(title: title2).first.state).to eq('draft')
        expect(response).to redirect_to(organization_seats_path(company))
        expect(flash[:notice]).to include('Successfully created')
      end

      it 'skips position types that already have seats' do
        create(:seat, title: title, seat_needed_by: Date.current)
        
        expect {
          post :create_missing_title_seats, params: { organization_id: company.id }
        }.not_to change { Seat.count }
      end
    end

    context 'without MAAP management permission' do
      before do
        person_teammate.update!(can_manage_maap: false)
      end

      it 'redirects with error' do
        post :create_missing_title_seats, params: { organization_id: company.id }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end
end

