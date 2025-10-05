require 'rails_helper'

RSpec.describe 'MaapSnapshot CheckInData Format Bug', type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  
  # Create assignments with the exact IDs from snapshot 110
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

  describe 'CheckInData format processing bug' do
    context 'when form_params contains check_in_data hash format' do
      it 'should fail by not processing the check_in_data format correctly' do
        # Form params that use the check_in_data hash format (like snapshot 110)
        form_params = {
          "check_in_data" => {
            "80" => {
              "check_in_id" => @emp_growth_check_in.id,
              "close_rating" => false,
              "final_rating" => "working_to_meet",
              "shared_notes" => "Lifeline - work - incomplete"
            },
            "81" => {
              "check_in_id" => @quarterly_check_in.id,
              "close_rating" => false,
              "final_rating" => "meeting",
              "shared_notes" => "Emp grow - meet - incomplete"
            }
          }
        }

        # Create a snapshot using the OLD method
        snapshot = MaapSnapshot.build_for_employee_with_changes(
          employee: employee,
          created_by: employee,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing check_in_data format processing bug',
          form_params: form_params
        )

        # Find assignments in the processed snapshot
        emp_growth_data = snapshot.maap_data['assignments'].find { |a| a['id'] == emp_growth_assignment.id }
        quarterly_data = snapshot.maap_data['assignments'].find { |a| a['id'] == quarterly_assignment.id }
        lifeline_data = snapshot.maap_data['assignments'].find { |a| a['id'] == lifeline_assignment.id }

        # Debug output to see what's happening
        puts "\n=== CHECK_IN_DATA FORMAT PROCESSING BUG ==="
        puts "Employee Growth Plan Champion (ID: 80):"
        puts "  shared_notes: '#{emp_growth_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{emp_growth_data['official_check_in']['official_rating']}'"
        
        puts "Quarterly Conversation Coordinator (ID: 81):"
        puts "  shared_notes: '#{quarterly_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{quarterly_data['official_check_in']['official_rating']}'"
        
        puts "Lifeline Interview Facilitator (ID: 84):"
        puts "  shared_notes: '#{lifeline_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{lifeline_data['official_check_in']['official_rating']}'"
        puts "==========================================\n"

        # Expected behavior: The check_in_data format should be processed correctly
        # Assignment 80 should get its check_in_data
        expect(emp_growth_data['official_check_in']['shared_notes']).to eq('Lifeline - work - incomplete')
        expect(emp_growth_data['official_check_in']['official_rating']).to eq('working_to_meet')
        
        # Assignment 81 should get its check_in_data
        expect(quarterly_data['official_check_in']['shared_notes']).to eq('Emp grow - meet - incomplete')
        expect(quarterly_data['official_check_in']['official_rating']).to eq('meeting')
        
        # Assignment 84 should NOT get check_in_data since it wasn't provided
        # It should keep its existing check-in data
        expect(lifeline_data['official_check_in']['shared_notes']).to eq('Existing lifeline notes')
        expect(lifeline_data['official_check_in']['official_rating']).to eq('exceeding')
        
        # This spec should FAIL because the check_in_data format is not being processed
        # The bug: The method doesn't know how to handle the check_in_data hash format
        # It's looking for check_in_#{assignment_id}_* format instead
      end
    end
  end
end


