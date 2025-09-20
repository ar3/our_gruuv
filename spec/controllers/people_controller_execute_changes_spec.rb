require 'rails_helper'

RSpec.describe PeopleController, type: :controller do
  let!(:organization) { create(:organization) }
  let!(:manager) { create(:person, current_organization: organization) }
  let!(:employee) { create(:person, current_organization: organization) }
  let!(:position_major_level) { create(:position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let!(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:employment) { create(:employment_tenure, person: employee, position: position, company: organization) }
  let!(:assignment1) { create(:assignment, title: 'Assignment 1') }
  
  before do
    # Set up position assignments
    create(:position_assignment, position: position, assignment: assignment1)
    
    # Set up employment for manager
    create(:employment_tenure, person: manager, position: position, company: organization)
    
    # Set up organization access for manager
    create(:person_organization_access, person: manager, organization: organization, can_manage_maap: true, can_manage_employment: true)
    
    # Mock authentication
    allow(controller).to receive(:current_person).and_return(manager)
    allow(controller).to receive(:authenticate_person!)
    
    # Mock authorization
    allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
    
    # Set up controller for testing
    controller.request.env['HTTP_ACCEPT'] = 'text/html'
  end

  describe 'GET #execute_changes' do
    let!(:maap_snapshot) do
      create(:maap_snapshot, 
        employee: employee, 
        created_by: manager, 
        company: organization,
        change_type: 'assignment_management',
        reason: 'Test execution'
      )
    end

    it 'renders the execute_changes page successfully' do
      get :execute_changes, params: { id: employee.id, maap_snapshot_id: maap_snapshot.id }
      
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:execute_changes)
      expect(controller.maap_snapshot).to eq(maap_snapshot)
    end

    it 'redirects if user is not the creator of the MaapSnapshot' do
      other_manager = create(:person, current_organization: organization)
      allow(controller).to receive(:current_person).and_return(other_manager)
      allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
      
      get :execute_changes, params: { id: employee.id, maap_snapshot_id: maap_snapshot.id }
      
      expect(response).to redirect_to(person_assignment_tenures_path(employee))
      expect(flash[:alert]).to include('not authorized')
    end

    it 'handles missing MaapSnapshot gracefully' do
      get :execute_changes, params: { id: employee.id, maap_snapshot_id: 99999 }
      
      expect(response).to redirect_to(person_assignment_tenures_path(employee))
      expect(flash[:alert]).to include('not found')
    end
  end

  describe 'private methods' do
    let!(:maap_snapshot) do
      create(:maap_snapshot, 
        employee: employee, 
        created_by: manager, 
        company: organization,
        change_type: 'assignment_management',
        reason: 'Test execution'
      )
    end

    describe '#load_assignments_and_check_ins' do
      it 'loads assignment data sorted by energy percentage' do
        create(:assignment_tenure, person: employee, assignment: assignment1, anticipated_energy_percentage: 20)
        
        controller.instance_variable_set(:@person, employee)
        controller.instance_variable_set(:@maap_snapshot, maap_snapshot)
        
        controller.send(:load_assignments_and_check_ins)
        
        assignment_data = controller.instance_variable_get(:@assignment_data)
        expect(assignment_data).to be_an(Array)
        expect(assignment_data.length).to eq(1)
        
        # Should be sorted by energy percentage (highest first)
        expect(assignment_data.first[:assignment]).to eq(assignment1)
      end
    end

    describe '#execute_maap_changes!' do
      it 'executes assignment changes successfully' do
        maap_snapshot.update!(
          maap_data: {
            employment_tenure: nil,
            assignments: [
              {
                id: assignment1.id,
                tenure: { anticipated_energy_percentage: 35, started_at: Date.current },
                employee_check_in: nil,
                manager_check_in: nil,
                official_check_in: nil
              }
            ],
            milestones: [],
            aspirations: []
          }
        )
        
        controller.instance_variable_set(:@person, employee)
        controller.instance_variable_set(:@maap_snapshot, maap_snapshot)
        
        result = controller.send(:execute_maap_changes!)
        expect(result).to be true
      end

      it 'handles execution errors gracefully' do
        maap_snapshot.update!(
          maap_data: {
            employment_tenure: nil,
            assignments: [
              {
                id: 99999, # Invalid assignment ID
                tenure: { anticipated_energy_percentage: 35, started_at: Date.current },
                employee_check_in: nil,
                manager_check_in: nil,
                official_check_in: nil
              }
            ],
            milestones: [],
            aspirations: []
          }
        )
        
        controller.instance_variable_set(:@person, employee)
        controller.instance_variable_set(:@maap_snapshot, maap_snapshot)
        
        result = controller.send(:execute_maap_changes!)
        expect(result).to be false
      end
    end

    describe '#update_assignment_tenure' do
      let!(:existing_tenure) { create(:assignment_tenure, person: employee, assignment: assignment1, anticipated_energy_percentage: 20) }

      it 'creates new tenure when energy changes' do
        controller.instance_variable_set(:@person, employee)
        
        tenure_data = {
          'anticipated_energy_percentage' => 35,
          'started_at' => Date.current.to_s
        }
        
        expect {
          controller.send(:update_assignment_tenure, assignment1, tenure_data)
        }.to change(AssignmentTenure, :count).by(1)
        
        # Check that old tenure was ended
        existing_tenure.reload
        expect(existing_tenure.ended_at).to eq(Date.current + 1.day)
        
        # Check that new tenure was created
        new_tenure = employee.assignment_tenures.where(assignment: assignment1).active.first
        expect(new_tenure.anticipated_energy_percentage).to eq(35)
        expect(new_tenure.started_at).to eq(Date.current)
      end

      it 'does not create new tenure when energy is the same' do
        controller.instance_variable_set(:@person, employee)
        
        tenure_data = {
          'anticipated_energy_percentage' => 20, # Same as existing
          'started_at' => Date.current.to_s
        }
        
        expect {
          controller.send(:update_assignment_tenure, assignment1, tenure_data)
        }.not_to change(AssignmentTenure, :count)
        
        # Check that existing tenure is still active
        existing_tenure.reload
        expect(existing_tenure.ended_at).to be_nil
      end

      it 'creates new tenure when no active tenure exists' do
        existing_tenure.update!(ended_at: Date.current + 1.day)
        controller.instance_variable_set(:@person, employee)
        
        tenure_data = {
          'anticipated_energy_percentage' => 35,
          'started_at' => Date.current.to_s
        }
        
        expect {
          controller.send(:update_assignment_tenure, assignment1, tenure_data)
        }.to change(AssignmentTenure, :count).by(1)
        
        # Check that new tenure was created
        new_tenure = employee.assignment_tenures.where(assignment: assignment1).active.first
        expect(new_tenure.anticipated_energy_percentage).to eq(35)
        expect(new_tenure.started_at).to eq(Date.current)
      end

      it 'ends tenure when energy is set to 0' do
        controller.instance_variable_set(:@person, employee)
        
        tenure_data = {
          'anticipated_energy_percentage' => 0,
          'started_at' => Date.current.to_s
        }
        
        expect {
          controller.send(:update_assignment_tenure, assignment1, tenure_data)
        }.not_to change(AssignmentTenure, :count)
        
        # Check that existing tenure was ended
        existing_tenure.reload
        expect(existing_tenure.ended_at).to eq(Date.current + 1.day)
      end
    end
  end
end