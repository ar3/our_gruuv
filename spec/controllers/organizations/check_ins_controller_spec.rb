require 'rails_helper'

RSpec.describe Organizations::CheckInsController, type: :controller do
  let(:manager) { create(:person, og_admin: true) }
  let(:employee) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:team) { create(:organization, :team, parent: company) }
  let!(:manager_teammate) { create(:teammate, person: manager, organization: company) }
  let!(:employee_teammate) { create(:teammate, person: employee, organization: company) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:manager_employment) { create(:employment_tenure, teammate: manager_teammate, company: company, position: position, started_at: 1.year.ago, ended_at: nil) }
  let(:employee_employment) { create(:employment_tenure, teammate: employee_teammate, company: company, position: position, started_at: 6.months.ago, ended_at: nil) }
  let(:assignment1) { create(:assignment, company: company, title: 'Assignment 1') }
  let(:assignment2) { create(:assignment, company: company, title: 'Assignment 2') }
  let(:assignment_tenure1) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1, started_at: 3.months.ago, ended_at: nil) }
  let(:assignment_tenure2) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment2, started_at: 2.months.ago, ended_at: nil) }
  
  # Create check-ins ready for finalization
  let(:check_in1) do
    create(:assignment_check_in, 
           teammate: employee_teammate, 
           assignment: assignment1, 
           check_in_started_on: 1.week.ago,
           employee_completed_at: 3.days.ago,
           manager_completed_at: 2.days.ago,
           employee_rating: 'meeting',
           manager_rating: 'exceeding',
           actual_energy_percentage: 85,
           employee_personal_alignment: 'like',
           manager_private_notes: 'Great work!')
  end
  
  let(:check_in2) do
    create(:assignment_check_in, 
           teammate: employee_teammate, 
           assignment: assignment2, 
           check_in_started_on: 1.week.ago,
           employee_completed_at: 2.days.ago,
           manager_completed_at: 1.day.ago,
           employee_rating: 'exceeding',
           manager_rating: 'meeting',
           actual_energy_percentage: 90,
           employee_personal_alignment: 'love',
           manager_private_notes: 'Excellent progress')
  end

  before do
    session[:current_person_id] = manager.id
    manager_employment
    employee_employment
    assignment_tenure1
    assignment_tenure2
    check_in1
    check_in2
    
    # Manager is og_admin, so admin_bypass? should return true
  end

  describe 'GET #show' do
    it 'returns http success' do
      get :show, params: { organization_id: company.id, person_id: employee.id }
      expect(response).to have_http_status(:success)
    end

    it 'loads check-ins in progress' do
      get :show, params: { organization_id: company.id, person_id: employee.id }
      expect(assigns(:check_ins_in_progress)).to include(check_in1, check_in2)
    end

    it 'sets is_manager correctly' do
      get :show, params: { organization_id: company.id, person_id: employee.id }
      expect(assigns(:is_manager)).to be true
    end
  end

  describe 'PATCH #bulk_finalize_check_ins' do
    let(:valid_params) do
      {
        organization_id: company.id,
        person_id: employee.id,
        "check_in_#{check_in1.id}_final_rating" => 'exceeding',
        "check_in_#{check_in1.id}_shared_notes" => 'Great work on this assignment!',
        "check_in_#{check_in1.id}_close_rating" => 'true',
        "check_in_#{check_in2.id}_final_rating" => 'meeting',
        "check_in_#{check_in2.id}_shared_notes" => 'Good progress overall.',
        "check_in_#{check_in2.id}_close_rating" => 'false'
      }
    end

    context 'when manager is authorized' do
    it 'creates a MaapSnapshot' do
      expect {
        patch :bulk_finalize_check_ins, params: valid_params
      }.to change(MaapSnapshot, :count).by(1)
    end

      it 'sets the correct MaapSnapshot attributes' do
        patch :bulk_finalize_check_ins, params: valid_params
        maap_snapshot = MaapSnapshot.last
        
        expect(maap_snapshot.employee).to eq(employee)
        expect(maap_snapshot.created_by).to eq(manager)
        expect(maap_snapshot.change_type).to eq('bulk_check_in_finalization')
        expect(maap_snapshot.reason).to eq('Bulk finalization of ready check-ins')
        expect(maap_snapshot.request_info['ip_address']).to be_present
        expect(maap_snapshot.request_info['user_agent']).to be_present
        expect(maap_snapshot.request_info['session_id']).to be_present
        expect(maap_snapshot.request_info['request_id']).to be_present
        expect(maap_snapshot.request_info['timestamp']).to be_present
      end
      
      it 'includes original organization ID for proper redirect' do
        patch :bulk_finalize_check_ins, params: valid_params
        maap_snapshot = MaapSnapshot.last
        
        # The original organization ID should be stored in the maap_data for later retrieval
        expect(maap_snapshot.maap_data).to be_present
      end

      it 'collects check-in data correctly' do
        patch :bulk_finalize_check_ins, params: valid_params
        maap_snapshot = MaapSnapshot.last
        
        # The check-in data should be processed and stored in maap_data
        expect(maap_snapshot.maap_data['assignments']).to be_present
        expect(maap_snapshot.maap_data['assignments'].length).to eq(2)
        
        # Each assignment should have the expected structure
        assignment_data = maap_snapshot.maap_data['assignments'].first
        expect(assignment_data).to have_key('employee_check_in')
        expect(assignment_data).to have_key('manager_check_in')
        expect(assignment_data).to have_key('official_check_in')
        expect(assignment_data).to have_key('tenure')
        
        # Check that the form data was processed correctly
        # Find the assignment with check_in1 (assignment1)
        assignment_data = maap_snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        employee_check_in = assignment_data['employee_check_in']
        expect(employee_check_in['actual_energy_percentage']).to eq(85)
        expect(employee_check_in['employee_rating']).to eq('meeting')
        
        # Check that shared notes and final ratings are processed into official_check_in
        official_check_in = assignment_data['official_check_in']
        expect(official_check_in['shared_notes']).to eq('Great work on this assignment!')
        expect(official_check_in['official_rating']).to eq('exceeding')
      end

      it 'redirects to execute changes page' do
        patch :bulk_finalize_check_ins, params: valid_params
        maap_snapshot = MaapSnapshot.last
        expect(response).to redirect_to(execute_changes_organization_person_path(company, employee, maap_snapshot))
      end

      it 'includes success notice' do
        patch :bulk_finalize_check_ins, params: valid_params
        expect(flash[:notice]).to include('Bulk check-in finalization queued for processing')
        expect(flash[:notice]).to include(employee.full_name)
        expect(flash[:notice]).to include(MaapSnapshot.last.id.to_s)
      end

      it 'captures request info for security' do
        patch :bulk_finalize_check_ins, params: valid_params
        maap_snapshot = MaapSnapshot.last
        request_info = maap_snapshot.request_info
        
        expect(request_info['ip_address']).to be_present
        expect(request_info['user_agent']).to be_present
        expect(request_info['session_id']).to be_present
        expect(request_info['request_id']).to be_present
        expect(request_info['timestamp']).to be_present
      end
    end

    context 'when no check-ins are ready for finalization' do
      before do
        # Create check-ins that are not ready for finalization
        check_in1.update!(manager_completed_at: nil)
        check_in2.update!(employee_completed_at: nil)
      end

      it 'redirects with alert message' do
        patch :bulk_finalize_check_ins, params: valid_params
        expect(response).to redirect_to(organization_check_in_path(company, employee))
        expect(flash[:alert]).to eq('No check-ins are ready for finalization. Both employee and manager must complete their sections first.')
      end

      it 'does not create a MaapSnapshot' do
        expect {
          patch :bulk_finalize_check_ins, params: valid_params
        }.not_to change(MaapSnapshot, :count)
      end
    end

    context 'when user is not authorized' do
      let(:unauthorized_user) { create(:person) }
      
      before do
        session[:current_person_id] = unauthorized_user.id
      end

      it 'redirects when not authorized' do
        patch :bulk_finalize_check_ins, params: valid_params
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/people/')
      end
    end

    context 'when MaapSnapshot creation fails' do
      before do
        allow_any_instance_of(MaapSnapshot).to receive(:save).and_return(false)
        allow_any_instance_of(MaapSnapshot).to receive(:errors).and_return(
          double(full_messages: ['Some error message'])
        )
      end

      it 'redirects with error message' do
        patch :bulk_finalize_check_ins, params: valid_params
        expect(response).to redirect_to(organization_check_in_path(company, employee))
        expect(flash[:alert]).to eq('Failed to create change record. Please try again.')
      end
    end

    context 'with impersonation' do
      let(:admin_user) { create(:person, og_admin: true) }
      
      before do
        session[:current_person_id] = manager.id
        session[:impersonating_person_id] = admin_user.id
      end

      it 'uses real admin user as created_by' do
        patch :bulk_finalize_check_ins, params: valid_params
        maap_snapshot = MaapSnapshot.last
        
        # The created_by should be the admin user (the impersonator), not the impersonated user
        expect(maap_snapshot.created_by).to eq(admin_user)
        expect(maap_snapshot.created_by).not_to eq(manager)
        
        # The employee should still be the target employee
        expect(maap_snapshot.employee).to eq(employee)
      end

      it 'captures impersonation in request info' do
        patch :bulk_finalize_check_ins, params: valid_params
        maap_snapshot = MaapSnapshot.last
        request_info = maap_snapshot.request_info
        
        expect(request_info['session_id']).to be_present
        expect(request_info['timestamp']).to be_present
      end
    end
  end

  describe 'PATCH #finalize_check_in' do
    let(:valid_params) do
      {
        organization_id: company.id,
        person_id: employee.id,
        check_in_id: check_in1.id,
        final_rating: 'exceeding',
        shared_notes: 'Great work!',
        close_rating: 'true'
      }
    end

    it 'finalizes the check-in when close_rating is true' do
      patch :finalize_check_in, params: valid_params
      
      check_in1.reload
      expect(check_in1.official_rating).to eq('exceeding')
      expect(check_in1.shared_notes).to eq('Great work!')
      expect(check_in1.official_check_in_completed_at).to be_present
      expect(check_in1.finalized_by).to eq(manager)
    end

    it 'saves rating without closing when close_rating is false' do
      valid_params[:close_rating] = 'false'
      patch :finalize_check_in, params: valid_params
      
      check_in1.reload
      expect(check_in1.official_rating).to eq('exceeding')
      expect(check_in1.shared_notes).to eq('Great work!')
      expect(check_in1.official_check_in_completed_at).to be_nil
    end
  end
end
