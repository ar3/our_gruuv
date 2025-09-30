require 'rails_helper'

RSpec.describe 'MaapSnapshot Old Method UI Duplication Bug', type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  
  # Create assignments with specific IDs to match the scenario
  let(:lifeline_assignment) { create(:assignment, company: organization, title: 'Lifeline Interview Facilitator', id: 84) }
  let(:emp_growth_assignment) { create(:assignment, company: organization, title: 'Employee Growth Plan Champion', id: 80) }
  let(:quarterly_assignment) { create(:assignment, company: organization, title: 'Quarterly Conversation Coordinator', id: 81) }

  before do
    # Set up employment tenure
    create(:employment_tenure, person: employee, company: organization)
    
    # Set up assignment tenures
    create(:assignment_tenure, person: employee, assignment: lifeline_assignment, anticipated_energy_percentage: 20)
    create(:assignment_tenure, person: employee, assignment: emp_growth_assignment, anticipated_energy_percentage: 50)
    create(:assignment_tenure, person: employee, assignment: quarterly_assignment, anticipated_energy_percentage: 30)
    
    # Set up check-ins with existing data (ready for finalization)
    create(:assignment_check_in, 
           person: employee, 
           assignment: lifeline_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           shared_notes: 'Existing lifeline notes',
           official_rating: 'exceeding')
           
    create(:assignment_check_in, 
           person: employee, 
           assignment: emp_growth_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           shared_notes: 'Existing emp growth notes',
           official_rating: 'exceeding')
           
    create(:assignment_check_in, 
           person: employee, 
           assignment: quarterly_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           shared_notes: 'Existing quarterly notes',
           official_rating: 'exceeding')
  end

  describe 'UI scenario reproduction with OLD method' do
    context 'when user updates Lifeline Interview Facilitator and Employee Growth Plan Champion' do
      it 'should fail by reproducing the cross-assignment duplication bug using the OLD method' do
        # Form params that match the exact UI scenario:
        # User updates Lifeline Interview Facilitator (ID: 84) with "Working to meet" and "Lifeline - Working - Incomplete"
        # User updates Employee Growth Plan Champion (ID: 80) with "Meeting" and "Emp Grow - Meet - Incomplete"
        # User does NOT update Quarterly Conversation Coordinator (ID: 81)
        form_params = {
          "check_in_84_final_rating" => 'working_to_meet',
          "check_in_84_shared_notes" => 'Lifeline - Working - Incomplete',
          "check_in_80_final_rating" => 'meeting',
          "check_in_80_shared_notes" => 'Emp Grow - Meet - Incomplete'
          # Note: No form params for assignment 81 (Quarterly Conversation Coordinator)
        }

        # Create a snapshot using the OLD method (this should reproduce the bug)
        snapshot = MaapSnapshot.build_for_employee_with_changes(
          employee: employee,
          created_by: employee,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing UI duplication bug reproduction with OLD method',
          form_params: form_params
        )

        # Find assignments in the processed snapshot
        lifeline_data = snapshot.maap_data['assignments'].find { |a| a['id'] == lifeline_assignment.id }
        emp_growth_data = snapshot.maap_data['assignments'].find { |a| a['id'] == emp_growth_assignment.id }
        quarterly_data = snapshot.maap_data['assignments'].find { |a| a['id'] == quarterly_assignment.id }

        # Debug output to see what's happening
        puts "\n=== OLD METHOD RESULTS ==="
        puts "Lifeline Interview Facilitator (ID: 84):"
        puts "  shared_notes: '#{lifeline_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{lifeline_data['official_check_in']['official_rating']}'"
        
        puts "Employee Growth Plan Champion (ID: 80):"
        puts "  shared_notes: '#{emp_growth_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{emp_growth_data['official_check_in']['official_rating']}'"
        
        puts "Quarterly Conversation Coordinator (ID: 81):"
        puts "  shared_notes: '#{quarterly_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{quarterly_data['official_check_in']['official_rating']}'"
        puts "========================\n"

        # Expected behavior (what should happen):
        # Lifeline Interview Facilitator should get its own form params
        expect(lifeline_data['official_check_in']['shared_notes']).to eq('Lifeline - Working - Incomplete')
        expect(lifeline_data['official_check_in']['official_rating']).to eq('working_to_meet')
        
        # Employee Growth Plan Champion should get its own form params
        expect(emp_growth_data['official_check_in']['shared_notes']).to eq('Emp Grow - Meet - Incomplete')
        expect(emp_growth_data['official_check_in']['official_rating']).to eq('meeting')
        
        # Quarterly Conversation Coordinator should NOT get form params since they weren't provided
        # It should keep its existing check-in data
        expect(quarterly_data['official_check_in']['shared_notes']).to eq('Existing quarterly notes')
        expect(quarterly_data['official_check_in']['official_rating']).to eq('exceeding')
        
        # This spec should FAIL by reproducing the buggy behavior:
        # The bug: Quarterly Conversation Coordinator gets Employee Growth Plan Champion's data
        # The bug: Employee Growth Plan Champion gets Lifeline Interview Facilitator's data
        
        # These assertions should fail, showing the duplication bug:
        expect(quarterly_data['official_check_in']['shared_notes']).not_to eq(emp_growth_data['official_check_in']['shared_notes'])
        expect(emp_growth_data['official_check_in']['shared_notes']).not_to eq(lifeline_data['official_check_in']['shared_notes'])
      end
    end
  end
end


