require 'rails_helper'

RSpec.describe AssignmentTenuresController, type: :controller do
  let!(:organization) { create(:organization) }
  let!(:manager) { create(:person, current_organization: organization) }
  let!(:employee) { create(:person, current_organization: organization) }
  let!(:position_major_level) { create(:position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let!(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:employment) { create(:employment_tenure, person: employee, position: position, company: organization) }
  let!(:assignment1) { create(:assignment, title: 'Assignment 1') }
  let!(:assignment2) { create(:assignment, title: 'Assignment 2') }
  let!(:assignment3) { create(:assignment, title: 'Assignment 3') }
  
  before do
    # Set up position assignments
    create(:position_assignment, position: position, assignment: assignment1)
    create(:position_assignment, position: position, assignment: assignment2)
    create(:position_assignment, position: position, assignment: assignment3)
    
    # Set up employment for both manager and employee
    employment # Employee employment
    create(:employment_tenure, person: manager, position: position, company: organization) # Manager employment
    
    # Set up organization access for manager
    create(:person_organization_access, person: manager, organization: organization, can_manage_maap: true, can_manage_employment: true)
    
    # Mock authentication
    allow(controller).to receive(:current_person).and_return(manager)
    allow(controller).to receive(:authenticate_person!)
  end

  describe 'PATCH #update' do
    context 'with multiple assignments having different states' do
      let!(:tenure1) { create(:assignment_tenure, person: employee, assignment: assignment1, anticipated_energy_percentage: 20) }
      let!(:tenure2) { create(:assignment_tenure, person: employee, assignment: assignment2, anticipated_energy_percentage: 30) }
      let!(:check_in1) { create(:assignment_check_in, person: employee, assignment: assignment1, actual_energy_percentage: 25, employee_rating: 'meeting') }
      let!(:check_in2) { create(:assignment_check_in, person: employee, assignment: assignment2, actual_energy_percentage: 35, manager_rating: 'exceeding') }

      context 'when updating only anticipated energy percentages' do
        let(:params) do
          {
            person_id: employee.id,
            "tenure_#{assignment1.id}_anticipated_energy" => '30',
            "tenure_#{assignment2.id}_anticipated_energy" => '40',
            "tenure_#{assignment3.id}_anticipated_energy" => '20'
          }
        end

        it 'creates new tenures for changed energy percentages' do
          # Disable authorization verification for this test
          allow(controller).to receive(:verify_authorized)
          
          # Mock the authorization to pass
          allow(controller).to receive(:authorize).and_return(true)
          
          # Mock the assignment data loading
          assignment_data = [
            { assignment: assignment1, tenure: tenure1, open_check_in: nil },
            { assignment: assignment2, tenure: tenure2, open_check_in: nil },
            { assignment: assignment3, tenure: nil, open_check_in: nil }
          ]
          allow(controller).to receive(:load_assignments_and_check_ins) do
            controller.instance_variable_set(:@assignment_data, assignment_data)
          end
          
          # Test the actual update logic
          expect {
            patch :update, params: params
          }.to change { AssignmentTenure.count }.by(3)
          
          expect(response).to have_http_status(:redirect)
        end

        it 'ends existing tenures when energy changes' do
          patch :update, params: params
          
          tenure1.reload
          tenure2.reload
          
          expect(tenure1.ended_at).to be_present
          expect(tenure2.ended_at).to be_present
        end

        it 'creates new tenure for assignment3' do
          patch :update, params: params
          
          new_tenure = AssignmentTenure.where(person: employee, assignment: assignment3).last
          expect(new_tenure.anticipated_energy_percentage).to eq(20)
          expect(new_tenure.started_at).to eq(Date.current)
        end
      end

      context 'when updating only check-in attributes' do
        let(:params) do
          {
            person_id: employee.id,
            "check_in_#{assignment1.id}_actual_energy" => '30',
            "check_in_#{assignment1.id}_employee_rating" => 'exceeding',
            "check_in_#{assignment1.id}_personal_alignment" => 'love',
            "check_in_#{assignment1.id}_employee_private_notes" => 'Great assignment!',
            "check_in_#{assignment2.id}_manager_rating" => 'working_to_meet',
            "check_in_#{assignment2.id}_manager_private_notes" => 'Needs improvement'
          }
        end

        it 'updates existing check-ins' do
          patch :update, params: params
          
          check_in1.reload
          check_in2.reload
          
          expect(check_in1.actual_energy_percentage).to eq(30)
          expect(check_in1.employee_rating).to eq('exceeding')
          expect(check_in1.employee_personal_alignment).to eq('love')
          expect(check_in1.employee_private_notes).to eq('Great assignment!')
          
          expect(check_in2.manager_rating).to eq('working_to_meet')
          expect(check_in2.manager_private_notes).to eq('Needs improvement')
        end

        it 'does not create new check-ins when updating existing ones' do
          expect {
            patch :update, params: params
          }.not_to change { AssignmentCheckIn.count }
        end
      end

      context 'when creating new check-ins' do
        let(:params) do
          {
            person_id: employee.id,
            "check_in_#{assignment3.id}_actual_energy" => '25',
            "check_in_#{assignment3.id}_employee_rating" => 'meeting',
            "check_in_#{assignment3.id}_personal_alignment" => 'like'
          }
        end

        it 'creates new check-in for assignment3' do
          expect {
            patch :update, params: params
          }.to change { AssignmentCheckIn.count }.by(1)
          
          new_check_in = AssignmentCheckIn.where(person: employee, assignment: assignment3).last
          expect(new_check_in.actual_energy_percentage).to eq(25)
          expect(new_check_in.employee_rating).to eq('meeting')
          expect(new_check_in.employee_personal_alignment).to eq('like')
          expect(new_check_in.check_in_started_on).to eq(Date.current)
        end
      end

      context 'when updating completion status' do
        let(:params) do
          {
            person_id: employee.id,
            "check_in_#{assignment1.id}_employee_complete" => '1',
            "check_in_#{assignment2.id}_manager_complete" => '1'
          }
        end

        it 'completes employee side for assignment1' do
          patch :update, params: params
          
          check_in1.reload
          expect(check_in1.employee_completed?).to be true
          expect(check_in1.employee_completed_at).to be_present
          expect(check_in1.employee_completed_by).to eq(manager)
        end

        it 'completes manager side for assignment2' do
          patch :update, params: params
          
          check_in2.reload
          expect(check_in2.manager_completed?).to be true
          expect(check_in2.manager_completed_at).to be_present
          expect(check_in2.manager_completed_by).to eq(manager)
        end
      end

      context 'when uncompleting check-ins' do
        before do
          # Make the existing check_in1 employee completed
          check_in1.update!(employee_completed_at: Time.current, employee_completed_by: manager)
        end
        
        let(:params) do
          {
            person_id: employee.id,
            "check_in_#{assignment1.id}_employee_complete" => '0'
          }
        end

        it 'uncompletes employee side' do
          patch :update, params: params
          
          check_in1.reload
          expect(check_in1.employee_completed?).to be false
          expect(check_in1.employee_completed_at).to be_nil
          expect(check_in1.employee_completed_by).to be_nil
        end
      end

      context 'when creating check-in and completing in same request' do
        let(:params) do
          {
            person_id: employee.id,
            "check_in_#{assignment3.id}_actual_energy" => '30',
            "check_in_#{assignment3.id}_employee_complete" => '1'
          }
        end

        it 'creates check-in and completes employee side' do
          expect {
            patch :update, params: params
          }.to change { AssignmentCheckIn.count }.by(1)
          
          new_check_in = AssignmentCheckIn.where(person: employee, assignment: assignment3).last
          expect(new_check_in.actual_energy_percentage).to eq(30)
          expect(new_check_in.employee_completed?).to be true
          expect(new_check_in.employee_completed_by).to eq(manager)
        end
      end

      context 'when no data changes' do
        let(:params) do
          {
            person_id: employee.id,
            "tenure_#{assignment1.id}_anticipated_energy" => '20' # Same as existing
          }
        end

        it 'does not create new tenures when energy is unchanged' do
          expect {
            patch :update, params: params
          }.not_to change { AssignmentTenure.count }
        end
      end

      context 'when mixing all update types' do
        let(:params) do
          {
            person_id: employee.id,
            # Change tenure energy
            "tenure_#{assignment1.id}_anticipated_energy" => '25',
            # Update existing check-in
            "check_in_#{assignment1.id}_actual_energy" => '30',
            "check_in_#{assignment1.id}_employee_complete" => '1',
            # Create new check-in
            "check_in_#{assignment3.id}_actual_energy" => '20',
            "check_in_#{assignment3.id}_employee_rating" => 'meeting',
            "check_in_#{assignment3.id}_manager_complete" => '1'
          }
        end

        it 'handles all update types in one request' do
          expect {
            patch :update, params: params
          }.to change { AssignmentTenure.count }.by(1) # New tenure for assignment1
            .and change { AssignmentCheckIn.count }.by(1) # New check-in for assignment3
          
          # Check tenure update
          new_tenure = AssignmentTenure.where(person: employee, assignment: assignment1).last
          expect(new_tenure.anticipated_energy_percentage).to eq(25)
          
          # Check existing check-in update
          check_in1.reload
          expect(check_in1.actual_energy_percentage).to eq(30)
          expect(check_in1.employee_completed?).to be true
          
          # Check new check-in creation
          new_check_in = AssignmentCheckIn.where(person: employee, assignment: assignment3).last
          expect(new_check_in.actual_energy_percentage).to eq(20)
          expect(new_check_in.employee_rating).to eq('meeting')
          expect(new_check_in.manager_completed?).to be true
        end
      end

      context 'when check-in creation fails validation' do
        let(:params) do
          {
            person_id: employee.id,
            "check_in_#{assignment3.id}_employee_rating" => 'invalid_rating'
          }
        end

        it 'handles validation errors gracefully' do
          expect {
            patch :update, params: params
          }.not_to change { AssignmentCheckIn.count }
          
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end
end
