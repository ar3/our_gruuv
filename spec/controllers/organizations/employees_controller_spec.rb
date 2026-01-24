require 'rails_helper'

RSpec.describe Organizations::EmployeesController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:team) { create(:organization, :team, parent: company) }
  let(:employee1) { create(:person) }
  let(:employee2) { create(:person) }
  let(:huddle_participant) { create(:person) }
  let!(:employee1_teammate) { create(:teammate, person: employee1, organization: company) }
  let!(:employee2_teammate) { create(:teammate, person: employee2, organization: company) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:title) { create(:title, organization: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:employment_tenure1) { create(:employment_tenure, teammate: employee1_teammate, company: company, position: position, started_at: 1.year.ago) }
  let(:employment_tenure2) { create(:employment_tenure, teammate: employee2_teammate, company: company, position: position, started_at: 6.months.ago) }
  let(:huddle_playbook) { create(:huddle_playbook, organization: team) }
  let(:huddle) { create(:huddle, huddle_playbook: huddle_playbook) }
  let(:huddle_participation) { create(:huddle_participant, huddle: huddle, teammate: create(:teammate, person: huddle_participant, organization: team)) }

  before do
    employment_tenure1
    employment_tenure2
    huddle_participation
    
    # Set first_employed_at on teammates to make them assigned employees
    employee1_teammate.update!(first_employed_at: 1.year.ago)
    employee2_teammate.update!(first_employed_at: 6.months.ago)
    
    # Create teammate for person and sign in
    person_teammate = create(:teammate, person: person, organization: company)
    person_teammate.update!(first_employed_at: 1.year.ago)
    session[:current_company_teammate_id] = person_teammate.id
    @current_company_teammate = nil if defined?(@current_company_teammate)
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct variables' do
      get :index, params: { organization_id: company.id }
      
      expect(assigns(:organization).id).to eq(company.id)
      # Compare by ID since controller may return different instances
      expect(assigns(:filtered_and_paginated_teammates).map(&:id)).to include(employee1_teammate.id, employee2_teammate.id)
      expect(assigns(:spotlight_stats)).to be_present
      expect(assigns(:spotlight_stats)[:assigned_employees]).to eq(2)
    end

    it 'includes huddle participants from child organizations' do
      get :index, params: { organization_id: company.id }
      
      # Debug: Check what's actually in the spotlight stats
      puts "Spotlight stats: #{assigns(:spotlight_stats)}"
      puts "Huddle participants count: #{assigns(:spotlight_stats)[:huddle_participants]}"
      puts "Total teammates: #{assigns(:spotlight_stats)[:total_teammates]}"
      
      # Debug: Check if huddle participation was created
      puts "Huddle participation exists: #{HuddleParticipant.exists?}"
      puts "Huddle participants count: #{HuddleParticipant.count}"
      
      # Debug: Check organization hierarchy
      puts "Company descendants: #{company.self_and_descendants.map(&:id)}"
      puts "All teammates in hierarchy: #{Teammate.for_organization_hierarchy(company).count}"
      puts "Teammates by organization:"
      Teammate.for_organization_hierarchy(company).each do |t|
        puts "  - #{t.person.display_name} (#{t.organization.name})"
      end
      
      # Should include participants from child organizations (team)
      expect(assigns(:spotlight_stats)[:huddle_participants]).to be > 0
    end

    it 'separates active employees from huddle-only participants' do
      get :index, params: { organization_id: company.id }
      
      # Active employees should not be in just_huddle_participants
      expect(assigns(:spotlight_stats)[:assigned_employees]).to eq(2)
      expect(assigns(:spotlight_stats)[:non_employee_participants]).to eq(1) # huddle_participant
    end

    it 'handles organizations with no employees gracefully' do
      empty_company = create(:organization, :company)
      # Create teammate for person in empty_company and switch session to it
      empty_teammate = create(:teammate, person: person, organization: empty_company)
      session[:current_company_teammate_id] = empty_teammate.id
      @current_company_teammate = nil if defined?(@current_company_teammate)
      
      get :index, params: { organization_id: empty_company.id }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:filtered_and_paginated_teammates)).to be_empty
      expect(assigns(:spotlight_stats)[:assigned_employees]).to eq(0)
    end

    describe 'check_ins_health spotlight' do
      context 'when spotlight is check_ins_health but view is not check_ins_health' do
        it 'calculates check_ins_health stats correctly' do
          get :index, params: { organization_id: company.id, spotlight: 'check_ins_health', view: 'list' }
          
          expect(response).to have_http_status(:success)
          expect(assigns(:spotlight_stats)).to be_present
          expect(assigns(:spotlight_stats)).to have_key(:total_employees)
          expect(assigns(:spotlight_stats)).to have_key(:all_healthy)
          expect(assigns(:spotlight_stats)).to have_key(:needing_attention)
          expect(assigns(:spotlight_stats)).to have_key(:completion_rate)
        end

        it 'sets needing_attention to a number, not nil' do
          get :index, params: { organization_id: company.id, spotlight: 'check_ins_health', view: 'list' }
          
          expect(assigns(:spotlight_stats)[:needing_attention]).not_to be_nil
          expect(assigns(:spotlight_stats)[:needing_attention]).to be_a(Integer)
        end

        it 'renders without error when needing_attention is 0' do
          # Create a finalized check-in within 90 days to make employee healthy
          finalized_check_in = create(:position_check_in, 
            :closed,
            teammate: employee1_teammate,
            employment_tenure: employment_tenure1,
            official_check_in_completed_at: 30.days.ago
          )
          
          get :index, params: { organization_id: company.id, spotlight: 'check_ins_health', view: 'list' }
          
          expect(response).to have_http_status(:success)
          expect(assigns(:spotlight_stats)[:needing_attention]).to be >= 0
        end
      end

      context 'when spotlight is check_ins_health and view is check_ins_health' do
        it 'calculates check_ins_health stats correctly' do
          get :index, params: { organization_id: company.id, spotlight: 'check_ins_health', view: 'check_ins_health' }
          
          expect(response).to have_http_status(:success)
          expect(assigns(:spotlight_stats)).to be_present
          expect(assigns(:spotlight_stats)).to have_key(:total_employees)
          expect(assigns(:spotlight_stats)).to have_key(:all_healthy)
          expect(assigns(:spotlight_stats)).to have_key(:needing_attention)
          expect(assigns(:spotlight_stats)).to have_key(:completion_rate)
          expect(assigns(:spotlight_stats)[:needing_attention]).not_to be_nil
        end
      end
    end

    describe 'managers_view' do
      let(:manager_person) { create(:person) }
      let(:manager_teammate) { CompanyTeammate.find(create(:teammate, person: manager_person, organization: company, first_employed_at: 1.year.ago).id) }

      before do
        # Update existing employment_tenure1 to have the manager
        employment_tenure1.update!(manager_teammate: manager_teammate)
        session[:current_company_teammate_id] = manager_teammate.id
        @current_company_teammate = nil if defined?(@current_company_teammate)
      end

      it 'renders managers_view when view is explicitly set' do
        get :index, params: { organization_id: company.id, manager_teammate_id: manager_teammate.id, view: 'managers_view' }
        expect(response).to have_http_status(:success)
        expect(assigns(:current_view)).to eq('managers_view')
      end

      it 'defaults to managers_view when manager_teammate_id is present and no view is set' do
        get :index, params: { organization_id: company.id, manager_teammate_id: manager_teammate.id }
        expect(response).to have_http_status(:success)
        expect(assigns(:current_view)).to eq('managers_view')
      end

      it 'does not default to managers_view when view is explicitly set to something else' do
        get :index, params: { organization_id: company.id, manager_teammate_id: manager_teammate.id, view: 'list' }
        expect(response).to have_http_status(:success)
        expect(assigns(:current_view)).to eq('list')
      end
    end
  end

  describe 'GET #audit' do
    let(:maap_manager) { create(:person) }
    let!(:maap_access) { create(:teammate, person: maap_manager, organization: company, can_manage_maap: true, can_manage_employment: true, first_employed_at: 1.year.ago) }
    let(:maap_snapshot1) { create(:maap_snapshot, employee: employee1, created_by: maap_manager, company: company, change_type: 'assignment_management') }
    let(:maap_snapshot2) { create(:maap_snapshot, employee: employee1, created_by: maap_manager, company: company, change_type: 'position_tenure') }

    before do
      maap_snapshot1
      maap_snapshot2
    end

    context 'when user has MAAP management permissions' do
      before do
        # Use existing teammate to avoid duplicate
        session[:current_company_teammate_id] = maap_access.id
        @current_company_teammate = nil if defined?(@current_company_teammate)
      end

      it 'returns http success' do
        get :audit, params: { organization_id: company.id, id: employee1.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns the correct variables' do
        get :audit, params: { organization_id: company.id, id: employee1.id }
        
        expect(assigns(:person)).to eq(employee1)
        expect(assigns(:maap_snapshots)).to include(maap_snapshot1, maap_snapshot2)
      end

      it 'only shows MAAP snapshots for the specific organization' do
        other_company = create(:organization, :company)
        other_snapshot = create(:maap_snapshot, employee: employee1, created_by: maap_manager, company: other_company)
        
        get :audit, params: { organization_id: company.id, id: employee1.id }
        
        expect(assigns(:maap_snapshots)).to include(maap_snapshot1, maap_snapshot2)
        expect(assigns(:maap_snapshots)).not_to include(other_snapshot)
      end
    end

    context 'when user does not have MAAP management permissions' do
      let(:unauthorized_user) { create(:person) }
      
      before do
        unauthorized_teammate = create(:teammate, person: unauthorized_user, organization: company, first_employed_at: 1.year.ago)
        sign_in_as_teammate(unauthorized_user, company)
      end

      it 'redirects when authorization fails' do
        get :audit, params: { organization_id: company.id, id: employee1.id }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is the person themselves' do
      before do
        sign_in_as_teammate(employee1, company)
      end

      it 'allows access to own audit view' do
        get :audit, params: { organization_id: company.id, id: employee1.id }
        expect(response).to have_http_status(:success)
      end
      
      it 'assigns pending snapshots when user is the person' do
        executed_snapshot = create(:maap_snapshot, 
          employee: employee1, 
          created_by: maap_manager, 
          company: company, 
          change_type: 'assignment_management',
          effective_date: 1.day.ago,
          employee_acknowledged_at: nil
        )
        
        get :audit, params: { organization_id: company.id, id: employee1.id }
        
        expect(assigns(:pending_snapshots)).to include(executed_snapshot)
      end
      
      it 'assigns acknowledged snapshots when user is the person' do
        acknowledged_snapshot = create(:maap_snapshot, 
          employee: employee1, 
          created_by: maap_manager, 
          company: company, 
          change_type: 'assignment_management',
          effective_date: 2.days.ago,
          employee_acknowledged_at: 1.day.ago
        )
        
        get :audit, params: { organization_id: company.id, id: employee1.id }
        
        expect(assigns(:acknowledged_snapshots)).to include(acknowledged_snapshot)
      end
      
      it 'renders the audit view template' do
        get :audit, params: { organization_id: company.id, id: employee1.id }
        expect(response).to render_template(:audit)
      end
      
      it 'renders audit view with snapshots' do
        get :audit, params: { organization_id: company.id, id: employee1.id }
        expect(response).to have_http_status(:success)
        expect(assigns(:maap_snapshots)).to include(maap_snapshot1, maap_snapshot2)
        # Verify the view renders without errors
        expect(response).to render_template(:audit)
      end
    end
  end

  describe 'GET #index with manager_distribution spotlight' do
    let(:manager) { create(:person) }
    let(:manager_teammate) { CompanyTeammate.find(create(:teammate, person: manager, organization: company, first_employed_at: 1.year.ago).id) }
    let(:direct_report) { create(:person) }
    let(:direct_report_teammate) { CompanyTeammate.find(create(:teammate, person: direct_report, organization: company, first_employed_at: 6.months.ago).id) }
    let!(:manager_employment) { create(:employment_tenure, teammate: manager_teammate, company: company, position: position, started_at: 1.year.ago) }
    let!(:direct_report_employment) do 
      create(:employment_tenure, 
        teammate: direct_report_teammate, 
        company: company, 
        position: position, 
        started_at: 6.months.ago,
        manager_teammate: manager_teammate
      ) 
    end

    before do
      # Ensure the test data is created
      manager_employment
      direct_report_employment
    end

    it 'calculates manager distribution stats correctly' do
      get :index, params: { 
        organization_id: company.id, 
        spotlight: 'manager_distribution',
        view: 'list'
      }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:spotlight_stats)).to be_present
      expect(assigns(:spotlight_stats)).to have_key(:active_managers)
      expect(assigns(:spotlight_stats)).to have_key(:non_managers)
      expect(assigns(:spotlight_stats)).to have_key(:management_levels)
      expect(assigns(:spotlight_stats)).to have_key(:max_level)
      expect(assigns(:spotlight_stats)).to have_key(:total_teammates)
    end

    it 'correctly identifies managers and non-managers' do
      get :index, params: { 
        organization_id: company.id, 
        spotlight: 'manager_distribution',
        view: 'list'
      }
      
      stats = assigns(:spotlight_stats)
      # Manager should be counted as an active manager
      expect(stats[:active_managers]).to be >= 1
      # Should have both managers and non-managers
      expect(stats[:total_teammates]).to be > stats[:active_managers]
    end

    it 'builds management levels correctly using manager_teammate_id' do
      get :index, params: { 
        organization_id: company.id, 
        spotlight: 'manager_distribution',
        view: 'list'
      }
      
      stats = assigns(:spotlight_stats)
      expect(stats[:management_levels]).to be_present
      expect(stats[:max_level]).to be >= 1
    end
  end

  describe 'GET #new_employee' do
    let(:manager_person) { create(:person) }
    let(:manager_teammate) { CompanyTeammate.find(create(:teammate, person: manager_person, organization: company, first_employed_at: 1.year.ago).id) }
    let!(:manager_employment) { create(:employment_tenure, teammate: manager_teammate, company: company, position: position, started_at: 1.year.ago) }
    let!(:direct_report_employment) do
      # End the existing employment_tenure1 first to avoid overlap
      employment_tenure1.update!(ended_at: 7.months.ago)
      create(:employment_tenure, teammate: employee1_teammate, company: company, position: position, started_at: 6.months.ago, manager_teammate: manager_teammate)
    end

    before do
      # Ensure user has manage_employment permission
      person_teammate = CompanyTeammate.find(session[:current_company_teammate_id])
      person_teammate.update!(can_manage_employment: true)
      @current_company_teammate = nil if defined?(@current_company_teammate)
    end

    it 'returns http success' do
      get :new_employee, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct variables' do
      get :new_employee, params: { organization_id: company.id }
      
      expect(assigns(:person)).to be_a(Person)
      expect(assigns(:person)).to be_new_record
      expect(assigns(:employment_tenure)).to be_a(EmploymentTenure)
      expect(assigns(:employment_tenure)).to be_new_record
      expect(assigns(:positions)).to include(position)
    end

    it 'loads managers and all_employees for the manager dropdown' do
      get :new_employee, params: { organization_id: company.id }
      
      expect(assigns(:managers)).to be_present
      expect(assigns(:all_employees)).to be_present
      # Manager should be in managers list
      expect(assigns(:managers).map(&:id)).to include(manager_teammate.id)
      # Non-manager employees should be in all_employees list
      expect(assigns(:all_employees).map(&:id)).to include(employee2_teammate.id)
      # Managers should not be in all_employees (no duplicates)
      expect(assigns(:all_employees).map(&:id)).not_to include(manager_teammate.id)
    end

    it 'renders the new_employee template' do
      get :new_employee, params: { organization_id: company.id }
      expect(response).to render_template(:new_employee)
    end

    it 'sorts positions alphabetically by title external_title' do
      # Create multiple position types with different external titles
      title_z = create(:title, organization: company, position_major_level: position_major_level, external_title: 'Zebra Position')
      title_a = create(:title, organization: company, position_major_level: position_major_level, external_title: 'Alpha Position')
      title_m = create(:title, organization: company, position_major_level: position_major_level, external_title: 'Middle Position')
      
      position_level_1 = create(:position_level, position_major_level: position_major_level, level: '1.0')
      position_level_2 = create(:position_level, position_major_level: position_major_level, level: '2.0')
      
      position_z = create(:position, title: title_z, position_level: position_level_1)
      position_a = create(:position, title: title_a, position_level: position_level_2)
      position_m = create(:position, title: title_m, position_level: position_level_1)
      
      get :new_employee, params: { organization_id: company.id }
      
      positions = assigns(:positions).to_a
      # Filter to only the positions we created for this test
      test_positions = positions.select { |p| [position_a.id, position_m.id, position_z.id].include?(p.id) }
      external_titles = test_positions.map { |p| p.title.external_title }
      
      # Verify positions are sorted alphabetically by external_title
      expect(external_titles).to eq(['Alpha Position', 'Middle Position', 'Zebra Position'])
    end
  end

  describe 'POST #create_employee' do
    let(:manager_person) { create(:person) }
    let(:manager_teammate) { CompanyTeammate.find(create(:teammate, person: manager_person, organization: company, first_employed_at: 1.year.ago).id) }
    let!(:manager_employment) { create(:employment_tenure, teammate: manager_teammate, company: company, position: position, started_at: 1.year.ago) }
    
    let(:valid_person_params) do
      {
        first_name: 'John',
        last_name: 'Doe',
        email: 'john.doe@example.com',
        timezone: 'Eastern Time (US & Canada)'
      }
    end
    
    let(:valid_employment_params) do
      {
        position_id: position.id,
        manager_teammate_id: manager_teammate.id,
        started_at: Date.current,
        employment_change_notes: 'New hire'
      }
    end

    before do
      # Ensure user has manage_employment permission
      person_teammate = CompanyTeammate.find(session[:current_company_teammate_id])
      person_teammate.update!(can_manage_employment: true)
      @current_company_teammate = nil if defined?(@current_company_teammate)
    end

    it 'creates a new person and employment' do
      expect {
        post :create_employee, params: {
          organization_id: company.id,
          person: valid_person_params,
          employment_tenure: valid_employment_params
        }
      }.to change { Person.count }.by(1)
        .and change { EmploymentTenure.count }.by(1)
        .and change { CompanyTeammate.count }.by(1)
    end

    it 'redirects to person profile on success' do
      post :create_employee, params: {
        organization_id: company.id,
        person: valid_person_params,
        employment_tenure: valid_employment_params
      }
      
      new_person = Person.find_by(email: 'john.doe@example.com')
      new_teammate = new_person.teammates.find_by(organization: company)
      expect(response).to redirect_to(organization_company_teammate_path(company, new_teammate))
    end

    it 'handles validation errors and loads manager data' do
      # Ensure there's a manager for the error case
      manager_employment
      
      post :create_employee, params: {
        organization_id: company.id,
        person: { first_name: '' }, # Invalid - missing required fields
        employment_tenure: valid_employment_params
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new_employee)
      # Managers and all_employees should be loaded (may be empty if no managers exist, but should be set)
      expect(assigns(:managers)).not_to be_nil
      expect(assigns(:all_employees)).not_to be_nil
    end

    it 'creates observable moment for new hire' do
      expect(ObservableMoments::CreateNewHireMomentService).to receive(:call).with(
        employment_tenure: an_instance_of(EmploymentTenure),
        created_by: person
      )
      
      post :create_employee, params: {
        organization_id: company.id,
        person: valid_person_params,
        employment_tenure: valid_employment_params
      }
    end

    it 'maps phone_number to unique_textable_phone_number' do
      person_with_phone = valid_person_params.merge(phone_number: '+1234567890')
      
      post :create_employee, params: {
        organization_id: company.id,
        person: person_with_phone,
        employment_tenure: valid_employment_params
      }
      
      new_person = Person.find_by(email: 'john.doe@example.com')
      expect(new_person.unique_textable_phone_number).to eq('+1234567890')
    end

    it 'displays validation errors when person is invalid' do
      post :create_employee, params: {
        organization_id: company.id,
        person: { first_name: '', last_name: '', email: '' }, # Invalid
        employment_tenure: valid_employment_params
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new_employee)
      expect(assigns(:person).errors).to be_present
    end

    it 'displays validation errors when employment_tenure is invalid' do
      post :create_employee, params: {
        organization_id: company.id,
        person: valid_person_params,
        employment_tenure: { position_id: nil, started_at: nil } # Invalid
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new_employee)
      expect(assigns(:employment_tenure).errors).to be_present
    end

    it 'handles other exceptions gracefully' do
      allow_any_instance_of(Person).to receive(:save!).and_raise(StandardError.new('Database error'))
      
      post :create_employee, params: {
        organization_id: company.id,
        person: valid_person_params,
        employment_tenure: valid_employment_params
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new_employee)
      expect(assigns(:error_message)).to be_present
    end

    it 'sets first_employed_at on teammate to the start date' do
      start_date = 1.month.ago.to_date
      employment_params_with_date = valid_employment_params.merge(started_at: start_date)
      
      post :create_employee, params: {
        organization_id: company.id,
        person: valid_person_params,
        employment_tenure: employment_params_with_date
      }
      
      new_person = Person.find_by(email: 'john.doe@example.com')
      new_teammate = new_person.teammates.find_by(organization: company)
      expect(new_teammate.first_employed_at.to_date).to eq(start_date)
    end

    it 'sets first_employed_at even when start date is in the future' do
      future_date = 1.month.from_now.to_date
      employment_params_with_date = valid_employment_params.merge(started_at: future_date)
      
      post :create_employee, params: {
        organization_id: company.id,
        person: valid_person_params,
        employment_tenure: employment_params_with_date
      }
      
      new_person = Person.find_by(email: 'john.doe@example.com')
      new_teammate = new_person.teammates.find_by(organization: company)
      expect(new_teammate.first_employed_at.to_date).to eq(future_date)
    end
  end
end

