require 'rails_helper'

RSpec.describe Organizations::AssignmentTenuresController, type: :controller do
  let!(:organization) { create(:organization) }
  let!(:manager) { create(:person, current_organization: organization) }
  let!(:employee) { create(:person, current_organization: organization) }
  let!(:position_major_level) { create(:position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let!(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_maap: true, can_manage_employment: true) }
  let!(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let!(:employment) { create(:employment_tenure, teammate: employee_teammate, position: position, company: organization) }
  let!(:assignment1) { create(:assignment, title: 'Assignment 1', company: organization) }
  let!(:assignment2) { create(:assignment, title: 'Assignment 2', company: organization) }
  let!(:assignment3) { create(:assignment, title: 'Assignment 3', company: organization) }
  
  before do
    # Set up position assignments
    create(:position_assignment, position: position, assignment: assignment1)
    create(:position_assignment, position: position, assignment: assignment2)
    create(:position_assignment, position: position, assignment: assignment3)
    
    # Set up employment for both manager and employee
    employment # Employee employment
    create(:employment_tenure, teammate: manager_teammate, position: position, company: organization) # Manager employment
    
    # Set up organization access for manager
    # manager_teammate already created above
    
    # Mock authentication
    allow(controller).to receive(:current_person).and_return(manager)
    allow(controller).to receive(:authenticate_person!)
  end

  describe 'GET #show' do
    it 'renders the assignment tenures page' do
      get :show, params: { organization_id: organization.id, id: employee.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:show)
    end

    it 'loads assignments and check-ins data' do
      # Create some test data
      create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1, anticipated_energy_percentage: 20)
      create(:assignment_check_in, teammate: employee_teammate, assignment: assignment1, actual_energy_percentage: 25)
      
      get :show, params: { organization_id: organization.id, id: employee.id }
      
      expect(assigns(:assignment_data)).to be_present
      expect(assigns(:assignment_data).length).to eq(1)
    end
  end

  describe 'PATCH #update' do
    context 'as a manager with valid parameters' do
      let(:valid_params) do
        {
          organization_id: organization.id,
          id: employee.id,
          reason: 'Testing MAAP snapshot creation'
        }
      end

      it 'creates a MaapSnapshot and redirects to execute_changes' do
        expect {
          patch :update, params: valid_params
        }.to change(MaapSnapshot, :count).by(1)
        
        expect(response).to have_http_status(:redirect)
        
        maap_snapshot = MaapSnapshot.last
        expect(maap_snapshot.employee).to eq(employee)
        expect(maap_snapshot.created_by).to eq(manager)
        expect(maap_snapshot.company.id).to eq(organization.id)
        expect(maap_snapshot.company.name).to eq(organization.name)
        expect(maap_snapshot.change_type).to eq('assignment_management')
        expect(maap_snapshot.reason).to eq('Testing MAAP snapshot creation')
        expect(maap_snapshot.pending?).to be true
        
        # Verify redirect to execute_changes
        expect(response).to redirect_to(execute_changes_organization_person_path(organization, employee, maap_snapshot))
      end

      it 'captures security information in request_info' do
        allow(request).to receive(:remote_ip).and_return('192.168.1.1')
        allow(request).to receive(:user_agent).and_return('Test Browser')
        allow(session).to receive(:id).and_return('test_session_123')
        
        patch :update, params: valid_params
        
        maap_snapshot = MaapSnapshot.last
        expect(maap_snapshot.request_info['ip_address']).to be_present
        expect(maap_snapshot.request_info['user_agent']).to be_present
        expect(maap_snapshot.request_info['session_id']).to be_present
        expect(maap_snapshot.request_info['request_id']).to be_present
        expect(maap_snapshot.request_info['timestamp']).to be_present
      end

      it 'includes current MAAP data in snapshot' do
        # Create some test data
        create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1, anticipated_energy_percentage: 20)
        create(:assignment_check_in, teammate: employee_teammate, assignment: assignment1, actual_energy_percentage: 25, employee_rating: 'meeting')
        
        patch :update, params: valid_params
        
        maap_snapshot = MaapSnapshot.last
        expect(maap_snapshot.maap_data['employment_tenure']).to be_present
        expect(maap_snapshot.maap_data['assignments']).to be_an(Array)
        expect(maap_snapshot.maap_data['assignments'].length).to eq(1)
        
        assignment_data = maap_snapshot.maap_data['assignments'].first
        expect(assignment_data['id']).to eq(assignment1.id)
        expect(assignment_data['tenure']['anticipated_energy_percentage']).to eq(20)
        expect(assignment_data['employee_check_in']['actual_energy_percentage']).to eq(25)
        expect(assignment_data['employee_check_in']['employee_rating']).to eq('meeting')
      end
    end

    context 'as a manager with tenure changes' do
      let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1, anticipated_energy_percentage: 20) }
      
      let(:tenure_change_params) do
        {
          organization_id: organization.id,
          id: employee.id,
          reason: 'Changing energy allocation',
          "tenure_#{assignment1.id}_anticipated_energy" => '5'
        }
      end

      it 'captures tenure changes in the snapshot' do
        patch :update, params: tenure_change_params
        
        maap_snapshot = MaapSnapshot.last
        assignment_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        
        expect(assignment_data['tenure']['anticipated_energy_percentage']).to eq(5)
        expect(assignment_data['tenure']['started_at']).to eq(assignment_tenure.started_at.to_s)
      end

      it 'creates new tenure when changing from 0% to non-zero' do
        # End the current tenure (must be after started_at)
        assignment_tenure.update!(ended_at: Date.current + 1.day)
        
        patch :update, params: tenure_change_params
        
        maap_snapshot = MaapSnapshot.last
        assignment_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        
        expect(assignment_data['tenure']['anticipated_energy_percentage']).to eq(5)
        expect(assignment_data['tenure']['started_at']).to eq(Date.current.to_s)
      end
    end

    context 'as a manager with check-in changes' do
      let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1, anticipated_energy_percentage: 20) }
      let!(:check_in) { create(:assignment_check_in, teammate: employee_teammate, assignment: assignment1, actual_energy_percentage: 15, employee_rating: 'meeting') }
      
      let(:check_in_change_params) do
        {
          organization_id: organization.id,
          id: employee.id,
          reason: 'Updating check-in data',
          "check_in_#{assignment1.id}_actual_energy" => '25',
          "check_in_#{assignment1.id}_employee_rating" => 'exceeding',
          "check_in_#{assignment1.id}_employee_private_notes" => 'Great progress this quarter',
          "check_in_#{assignment1.id}_personal_alignment" => 'love',
          "check_in_#{assignment1.id}_employee_complete" => '1'
        }
      end

      it 'captures employee check-in changes' do
        patch :update, params: check_in_change_params
        
        maap_snapshot = MaapSnapshot.last
        assignment_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        
        expect(assignment_data['employee_check_in']['actual_energy_percentage']).to eq(25)
        expect(assignment_data['employee_check_in']['employee_rating']).to eq('exceeding')
        expect(assignment_data['employee_check_in']['employee_private_notes']).to eq('Great progress this quarter')
        expect(assignment_data['employee_check_in']['employee_personal_alignment']).to eq('love')
        expect(assignment_data['employee_check_in']['employee_completed_at']).to be_present
      end

      it 'captures manager check-in changes' do
        manager_params = check_in_change_params.merge(
          "check_in_#{assignment1.id}_manager_rating" => 'exceeding',
          "check_in_#{assignment1.id}_manager_private_notes" => 'Excellent work',
          "check_in_#{assignment1.id}_manager_complete" => '1'
        )
        
        patch :update, params: manager_params
        
        maap_snapshot = MaapSnapshot.last
        assignment_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        
        expect(assignment_data['manager_check_in']['manager_rating']).to eq('exceeding')
        expect(assignment_data['manager_check_in']['manager_private_notes']).to eq('Excellent work')
        expect(assignment_data['manager_check_in']['manager_completed_at']).to be_present
      end

      it 'creates new check-in when none exists' do
        check_in.destroy!
        
        patch :update, params: check_in_change_params
        
        maap_snapshot = MaapSnapshot.last
        assignment_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        
        expect(assignment_data['employee_check_in']).to be_present
        expect(assignment_data['employee_check_in']['actual_energy_percentage']).to eq(25)
        expect(assignment_data['employee_check_in']['employee_rating']).to eq('exceeding')
      end
    end

    # Note: Authorization testing is complex in controller specs due to Pundit integration
    # The core authorization logic is tested in integration specs and policy specs

    context 'when MaapSnapshot creation fails' do
      before do
        allow(MaapSnapshot).to receive(:build_for_employee_with_changes).and_return(
          double(save: false, errors: double(full_messages: ['Test error']))
        )
      end

      it 'redirects back with alert' do
        patch :update, params: { organization_id: organization.id, id: employee.id }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_person_check_ins_path(organization, employee))
      end
    end
  end

  describe 'GET #choose_assignments' do
    it 'renders the choose assignments page' do
      get :choose_assignments, params: { organization_id: organization.id, id: employee.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:choose_assignments)
    end
  end
end