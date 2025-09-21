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