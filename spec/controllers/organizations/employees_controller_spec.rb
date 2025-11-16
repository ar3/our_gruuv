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
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
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
  end

  describe 'GET #audit' do
    let(:maap_manager) { create(:person) }
    let!(:maap_access) { create(:teammate, person: maap_manager, organization: company, can_manage_maap: true) }
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
        unauthorized_teammate = create(:teammate, person: unauthorized_user, organization: company)
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
end

