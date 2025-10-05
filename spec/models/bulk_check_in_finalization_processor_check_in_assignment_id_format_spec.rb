require 'rails_helper'

RSpec.describe 'BulkCheckInFinalizationProcessor CheckInAssignmentId Format', type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  
  # Create assignments with the exact IDs from snapshot 108
  let(:emp_growth_assignment) { create(:assignment, company: organization, title: 'Employee Growth Plan Champion', id: 80) }
  let(:quarterly_assignment) { create(:assignment, company: organization, title: 'Quarterly Conversation Coordinator', id: 81) }
  let(:lifeline_assignment) { create(:assignment, company: organization, title: 'Lifeline Interview Facilitator', id: 84) }

  before do
    # Set up employment tenure
    create(:employment_tenure, teammate: employee_teammate, company: organization)
    
    # Set up assignment tenures
    create(:assignment_tenure, teammate: employee_teammate, assignment: emp_growth_assignment, anticipated_energy_percentage: 50)
    create(:assignment_tenure, teammate: employee_teammate, assignment: quarterly_assignment, anticipated_energy_percentage: 30)
    create(:assignment_tenure, teammate: employee_teammate, assignment: lifeline_assignment, anticipated_energy_percentage: 20)
    
    # Set up check-ins with existing data (ready for finalization)
    @emp_growth_check_in = create(:assignment_check_in, 
           teammate: employee_teammate, 
           assignment: emp_growth_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           shared_notes: 'Existing emp growth notes',
           official_rating: 'exceeding')
           
    @quarterly_check_in = create(:assignment_check_in, 
           teammate: employee_teammate, 
           assignment: quarterly_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           shared_notes: 'Existing quarterly notes',
           official_rating: 'exceeding')
           
    @lifeline_check_in = create(:assignment_check_in, 
           teammate: employee_teammate, 
           assignment: lifeline_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           shared_notes: 'Existing lifeline notes',
           official_rating: 'exceeding')
  end

  describe 'CheckInAssignmentId format processing' do
    context 'when form_params contains check_in_#{assignment_id}_* format' do
      it 'should work correctly with the check_in_#{assignment_id}_* format' do
        # Form params that use the check_in_#{assignment_id}_* format (like snapshot 108):
        form_params = {
          "check_in_80_shared_notes" => 'Lifeline - Working - Incomplete',
          "check_in_80_final_rating" => 'working_to_meet',
          "check_in_81_shared_notes" => 'Emp Grow - Meet - Incomplete',
          "check_in_81_final_rating" => 'meeting'
          # Note: No form params for assignment 84 (Lifeline Interview Facilitator)
        }

        # Create a snapshot without maap_data
        snapshot = MaapSnapshot.build_for_employee_without_maap_data(
          employee: employee,
          created_by: employee,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing check_in_#{assignment_id}_* format in processor',
          form_params: form_params
        )

        # Process the snapshot with the processor
        snapshot.process_with_processor!

        # Find assignments in the processed snapshot
        emp_growth_data = snapshot.maap_data['assignments'].find { |a| a['id'] == emp_growth_assignment.id }
        quarterly_data = snapshot.maap_data['assignments'].find { |a| a['id'] == quarterly_assignment.id }
        lifeline_data = snapshot.maap_data['assignments'].find { |a| a['id'] == lifeline_assignment.id }

        # Debug output to see what's happening
        puts "\n=== PROCESSOR CHECK_IN_ASSIGNMENT_ID_* FORMAT ==="
        puts "Employee Growth Plan Champion (ID: 80):"
        puts "  shared_notes: '#{emp_growth_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{emp_growth_data['official_check_in']['official_rating']}'"
        
        puts "Quarterly Conversation Coordinator (ID: 81):"
        puts "  shared_notes: '#{quarterly_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{quarterly_data['official_check_in']['official_rating']}'"
        
        puts "Lifeline Interview Facilitator (ID: 84):"
        puts "  shared_notes: '#{lifeline_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{lifeline_data['official_check_in']['official_rating']}'"
        puts "===============================================\n"

        # Expected behavior: Each assignment should get its own form data
        # Assignment 80 should get its form data
        expect(emp_growth_data['official_check_in']['shared_notes']).to eq('Lifeline - Working - Incomplete')
        expect(emp_growth_data['official_check_in']['official_rating']).to eq('working_to_meet')
        
        # Assignment 81 should get its form data
        expect(quarterly_data['official_check_in']['shared_notes']).to eq('Emp Grow - Meet - Incomplete')
        expect(quarterly_data['official_check_in']['official_rating']).to eq('meeting')
        
        # Assignment 84 should NOT get form data since it wasn't provided
        # It should keep its existing check-in data
        expect(lifeline_data['official_check_in']['shared_notes']).to eq('Existing lifeline notes')
        expect(lifeline_data['official_check_in']['official_rating']).to eq('exceeding')
        
        # This spec should PASS because the check_in_#{assignment_id}_* format should work correctly
      end
    end
  end
end
