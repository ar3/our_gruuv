require 'rails_helper'

RSpec.describe Organizations::PeopleController, type: :controller do
  let!(:organization) { create(:organization) }
  let!(:manager) { create(:person, current_organization: organization) }
  let!(:employee) { create(:person, current_organization: organization) }
  let!(:position_major_level) { create(:position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let!(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:employment) { create(:employment_tenure, person: employee, position: position, company: organization) }
  let!(:assignment1) { create(:assignment, title: 'Assignment 1', company: organization) }
  
  before do
    # Set up position assignments
    create(:position_assignment, position: position, assignment: assignment1)
    
    # Set up employment for manager
    create(:employment_tenure, person: manager, position: position, company: organization)
    
    # Set up organization access for manager
    create(:teammate, person: manager, organization: organization, can_manage_maap: true, can_manage_employment: true)
    
    # Mock authentication
    allow(controller).to receive(:current_person).and_return(manager)
    allow(controller).to receive(:authenticate_person!)
    
    # Set organization ID in params
    controller.params[:organization_id] = organization.id
    
    # Mock authorization
    allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
    
    # Set up controller for testing
    controller.request.env['HTTP_ACCEPT'] = 'text/html'
  end

  describe 'GET #execute_changes' do
    let!(:assignment2) { create(:assignment, title: 'Assignment 2', company: organization) }
    let!(:assignment3) { create(:assignment, title: 'Assignment 3', company: organization) }
    
    before do
      # Set up position assignments
      create(:position_assignment, position: position, assignment: assignment2)
      create(:position_assignment, position: position, assignment: assignment3)
    end

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
      get :execute_changes, params: { organization_id: organization.id, id: employee.id, maap_snapshot_id: maap_snapshot.id }
      
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:execute_changes)
        expect(assigns(:maap_snapshot)).to eq(maap_snapshot)
    end

    context 'with mixed check-in states' do
      let!(:tenure1) { create(:assignment_tenure, person: employee, assignment: assignment1, anticipated_energy_percentage: 30) }
      let!(:tenure2) { create(:assignment_tenure, person: employee, assignment: assignment2, anticipated_energy_percentage: 40) }
      let!(:tenure3) { create(:assignment_tenure, person: employee, assignment: assignment3, anticipated_energy_percentage: 20) }
      
      # Assignment 1: Has open check-in with employee data
      let!(:check_in1) do
        create(:assignment_check_in, 
          person: employee, 
          assignment: assignment1, 
          check_in_started_on: Date.current,
          actual_energy_percentage: 25,
          employee_rating: 'meeting',
          employee_private_notes: 'Employee notes',
          employee_personal_alignment: 'like'
        )
      end
      
      # Assignment 2: Has open check-in with manager data
      let!(:check_in2) do
        create(:assignment_check_in, 
          person: employee, 
          assignment: assignment2, 
          check_in_started_on: Date.current,
          manager_rating: 'exceeding',
          manager_private_notes: 'Manager notes'
        )
      end
      
      # Assignment 3: No open check-in (this is the key test case)
      
      let!(:maap_snapshot_with_mixed_data) do
        create(:maap_snapshot, 
          employee: employee, 
          created_by: manager, 
          company: organization,
          change_type: 'assignment_management',
          reason: 'Test mixed check-in states',
          maap_data: {
            employment_tenure: nil,
            assignments: [
              {
                id: assignment1.id,
                tenure: { anticipated_energy_percentage: 35, started_at: Date.current },
                employee_check_in: {
                  actual_energy_percentage: 30,
                  employee_rating: 'exceeding',
                  employee_private_notes: 'Updated employee notes',
                  employee_personal_alignment: 'love'
                },
                manager_check_in: nil,
                official_check_in: nil
              },
              {
                id: assignment2.id,
                tenure: { anticipated_energy_percentage: 45, started_at: Date.current },
                employee_check_in: nil,
                manager_check_in: {
                  manager_rating: 'meeting',
                  manager_private_notes: 'Updated manager notes'
                },
                official_check_in: nil
              },
              {
                id: assignment3.id,
                tenure: { anticipated_energy_percentage: 25, started_at: Date.current },
                employee_check_in: {
                  actual_energy_percentage: 20,
                  employee_rating: 'exceeding',
                  employee_private_notes: 'Test notes',
                  employee_personal_alignment: 'love'
                },
                manager_check_in: nil,
                official_check_in: nil
              }
            ],
            milestones: [],
            aspirations: []
          }
        )
      end

      it 'handles assignments with mixed check-in states correctly' do
        get :execute_changes, params: { organization_id: organization.id, id: employee.id, maap_snapshot_id: maap_snapshot_with_mixed_data.id }
        
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:execute_changes)
        
        # Verify that the page loads without errors
        expect(assigns(:assignment_data)).to be_present
        expect(assigns(:assignment_data).length).to eq(3)
      end

      it 'detects changes correctly for assignments with and without check-ins' do
        controller.instance_variable_set(:@person, employee)
        controller.instance_variable_set(:@maap_snapshot, maap_snapshot_with_mixed_data)
        
        # Test change detection for assignment with open check-in
        expect(controller.send(:assignment_has_changes?, assignment1)).to be true
        
        # Test change detection for assignment with open check-in
        expect(controller.send(:assignment_has_changes?, assignment2)).to be true
        
        # Test change detection for assignment without open check-in
        expect(controller.send(:assignment_has_changes?, assignment3)).to be true
      end

      it 'executes changes correctly for mixed check-in states' do
        controller.instance_variable_set(:@person, employee)
        controller.instance_variable_set(:@maap_snapshot, maap_snapshot_with_mixed_data)
        
        # Execute changes
        result = controller.send(:execute_maap_changes!)
        expect(result).to be true
        
        # Verify tenure changes
        tenure1.reload
        expect(tenure1.ended_at).to be_present
        
        new_tenure1 = employee.assignment_tenures.where(assignment: assignment1).active.first
        expect(new_tenure1.anticipated_energy_percentage).to eq(35)
        
        # Verify check-in changes for assignment with open check-in
        # Manager should only be able to update manager fields, not employee fields
        check_in1.reload
        expect(check_in1.actual_energy_percentage).to eq(25) # Should remain unchanged (employee field)
        expect(check_in1.employee_rating).to eq('meeting') # Should remain unchanged (employee field)
        expect(check_in1.employee_private_notes).to eq('Employee notes') # Should remain unchanged (employee field)
        expect(check_in1.employee_personal_alignment).to eq('like') # Should remain unchanged (employee field)
        
        # Verify check-in changes for assignment with open check-in
        check_in2.reload
        expect(check_in2.manager_rating).to eq('meeting')
        expect(check_in2.manager_private_notes).to eq('Updated manager notes')
        
        # Verify check-in was created for assignment3 (since it has proposed check-in data)
        # But manager can't update employee fields, so they should remain nil
        check_in3 = AssignmentCheckIn.where(person: employee, assignment: assignment3).open.first
        expect(check_in3).to be_present
        expect(check_in3.actual_energy_percentage).to be_nil # Manager can't update employee fields
        expect(check_in3.employee_rating).to be_nil # Manager can't update employee fields
        expect(check_in3.employee_private_notes).to be_nil # Manager can't update employee fields
        expect(check_in3.employee_personal_alignment).to be_nil # Manager can't update employee fields
      end

      it 'handles nil check_in gracefully in MaapChangeDetectionService' do
        # This test should now pass - the service should handle nil check_in gracefully
        # instead of raising NoMethodError
        
        # Create the service directly with person: nil to test the fix
        service = MaapChangeDetectionService.new(
          person: nil, 
          maap_snapshot: maap_snapshot_with_mixed_data, 
          current_user: manager
        )
        
        # This should now return false instead of raising an error
        result = service.send(:can_update_employee_check_in_fields?, nil)
        expect(result).to be false
        
        # Test the manager authorization methods - these should handle nil person gracefully
        # by returning false instead of crashing
        result2 = service.send(:can_update_manager_check_in_fields?, nil)
        expect(result2).to be false
        
        result3 = service.send(:can_finalize_check_in?, nil)
        expect(result3).to be false
      end

      it 'allows employee to create new check-in when no open check-in exists' do
        # This test should now PASS - employee should be able to create new check-ins
        
        # Set up: employee trying to create a check-in for assignment3 (no existing check-in)
        # Override the current_person mock to return employee instead of manager
        allow(controller).to receive(:current_person).and_return(employee)
        controller.instance_variable_set(:@person, employee)
        controller.instance_variable_set(:@maap_snapshot, maap_snapshot_with_mixed_data)
        
        # Verify no check-in exists for assignment3
        existing_check_in = AssignmentCheckIn.where(person: employee, assignment: assignment3).open.first
        expect(existing_check_in).to be_nil
        
        # Execute changes - this should create a new check-in for assignment3
        result = controller.send(:execute_maap_changes!)
        expect(result).to be true
        
        # Verify new check-in was created with employee data
        new_check_in = AssignmentCheckIn.where(person: employee, assignment: assignment3).open.first
        expect(new_check_in).to be_present
        expect(new_check_in.actual_energy_percentage).to eq(20)
        expect(new_check_in.employee_rating).to eq('exceeding')
        expect(new_check_in.employee_private_notes).to eq('Test notes')
        expect(new_check_in.employee_personal_alignment).to eq('love')
      end
    end

    it 'redirects if user is not the creator of the MaapSnapshot' do
      other_manager = create(:person, current_organization: organization)
      allow(controller).to receive(:current_person).and_return(other_manager)
      allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
      
      get :execute_changes, params: { organization_id: organization.id, id: employee.id, maap_snapshot_id: maap_snapshot.id }
      
      expect(response).to redirect_to(organization_assignment_tenure_path(organization, employee))
      expect(flash[:alert]).to include('not authorized')
    end

    it 'handles missing MaapSnapshot gracefully' do
      get :execute_changes, params: { organization_id: organization.id, id: employee.id, maap_snapshot_id: 99999 }
      
      expect(response).to redirect_to(organization_assignment_tenure_path(organization, employee))
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
        
        service = MaapChangeExecutionService.new(
          maap_snapshot: nil,
          current_user: employee
        )
        service.instance_variable_set(:@person, employee)
        
        expect {
          service.send(:update_assignment_tenure, assignment1, tenure_data)
        }.to change(AssignmentTenure, :count).by(1)
        
        # Check that old tenure was ended
        existing_tenure.reload
        expect(existing_tenure.ended_at).to eq(Date.current)
        
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
        
        service = MaapChangeExecutionService.new(
          maap_snapshot: nil,
          current_user: employee
        )
        service.instance_variable_set(:@person, employee)
        
        expect {
          service.send(:update_assignment_tenure, assignment1, tenure_data)
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
        
        service = MaapChangeExecutionService.new(
          maap_snapshot: nil,
          current_user: employee
        )
        service.instance_variable_set(:@person, employee)
        
        expect {
          service.send(:update_assignment_tenure, assignment1, tenure_data)
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
        
        service = MaapChangeExecutionService.new(
          maap_snapshot: nil,
          current_user: employee
        )
        service.instance_variable_set(:@person, employee)
        
        expect {
          service.send(:update_assignment_tenure, assignment1, tenure_data)
        }.not_to change(AssignmentTenure, :count)
        
        # Check that existing tenure was ended
        existing_tenure.reload
        expect(existing_tenure.ended_at).to eq(Date.current)
      end
    end

    describe 'privacy helper methods' do
          describe '#can_see_manager_private_data?' do
            context 'when current person is a manager of the employee' do
              before do
                # Set up manager-employee relationship
                allow(controller).to receive(:current_person).and_return(manager)
                allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
              end

              it 'returns true for manager viewing employee data' do
                result = controller.send(:can_see_manager_private_data?, employee)
                expect(result).to be true
              end
            end

            context 'when current person is the employee themselves' do
              before do
                allow(controller).to receive(:current_person).and_return(employee)
                # Even if the policy would return true, the helper should return false for self-viewing
                allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
              end

              it 'returns false for employee viewing their own manager data' do
                result = controller.send(:can_see_manager_private_data?, employee)
                expect(result).to be false
              end
            end

            context 'when current person has no management relationship' do
              let!(:other_person) { create(:person, current_organization: organization) }

              before do
                allow(controller).to receive(:current_person).and_return(other_person)
                allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(false)
              end

              it 'returns false for non-manager viewing employee data' do
                result = controller.send(:can_see_manager_private_data?, employee)
                expect(result).to be false
              end
            end
          end

      describe '#format_private_field_value' do
        context 'when user can see manager data' do
          it 'returns the actual value when present' do
            result = controller.send(:format_private_field_value, 'Exceeding Expectations', true, 'Amy', 'manager')
            expect(result).to eq('Exceeding Expectations')
          end

          it 'returns "<not set>" when value is blank' do
            result = controller.send(:format_private_field_value, '', true, 'Amy', 'manager')
            expect(result).to eq('<not set>')
          end

          it 'returns "<not set>" when value is nil' do
            result = controller.send(:format_private_field_value, nil, true, 'Amy', 'manager')
            expect(result).to eq('<not set>')
          end
        end

            context 'when user cannot see manager data' do
              it 'returns privacy message for manager fields' do
                result = controller.send(:format_private_field_value, 'Exceeding Expectations', false, 'Amy', 'manager')
                expect(result).to eq("<only visible to Amy's managers>")
              end

              it 'returns privacy message for employee fields' do
                result = controller.send(:format_private_field_value, 'Great work!', false, 'Amy', 'employee')
                expect(result).to eq('<only visible to Amy>')
              end
            end
      end
    end
  end
end