require 'rails_helper'

RSpec.describe 'BulkCheckInFinalizationProcessor Snapshot 112 Complete Duplication Bug', type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  
  # Create assignments with the exact IDs from snapshot 112
  let(:emp_growth_assignment) { create(:assignment, company: organization, title: 'Employee Growth Plan Champion', id: 80) }
  let(:quarterly_assignment) { create(:assignment, company: organization, title: 'Quarterly Conversation Coordinator', id: 81) }
  let(:lifeline_assignment) { create(:assignment, company: organization, title: 'Lifeline Interview Facilitator', id: 84) }

  before do
    # Set up employment tenure
    create(:employment_tenure, person: employee, company: organization)
    
    # Set up assignment tenures
    create(:assignment_tenure, person: employee, assignment: emp_growth_assignment, anticipated_energy_percentage: 50)
    create(:assignment_tenure, person: employee, assignment: quarterly_assignment, anticipated_energy_percentage: 30)
    create(:assignment_tenure, person: employee, assignment: lifeline_assignment, anticipated_energy_percentage: 20)
    
    # Set up check-ins with existing data (ready for finalization)
    # Note: We need to create check-ins with specific IDs to match the check_in_data
    @emp_growth_check_in = create(:assignment_check_in, 
           person: employee, 
           assignment: emp_growth_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           shared_notes: 'Existing emp growth notes',
           official_rating: 'exceeding')
           
    @quarterly_check_in = create(:assignment_check_in, 
           person: employee, 
           assignment: quarterly_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           shared_notes: 'Existing quarterly notes',
           official_rating: 'exceeding')
           
    @lifeline_check_in = create(:assignment_check_in, 
           person: employee, 
           assignment: lifeline_assignment, 
           employee_completed_at: Time.current, 
           manager_completed_at: Time.current,
           shared_notes: 'Existing lifeline notes',
           official_rating: 'exceeding')
  end

  describe 'Snapshot 112 complete duplication bug in processor' do
    context 'when form_params contains all the fields from snapshot 112' do
      it 'should fail by reproducing the exact duplication bug from snapshot 112' do
        # Form params that exactly match snapshot 112 (all fields):
        form_params = {
          "id" => "881",
          "action" => "bulk_finalize_check_ins",
          "commit" => "Save Check-Ins",
          "_method" => "patch",
          "controller" => "organizations/check_ins",
          "check_in_data" => {
            "80" => {
              "check_in_id" => 80,  # This is actually the assignment_id, not the check-in ID
              "close_rating" => false,
              "final_rating" => "working_to_meet",
              "shared_notes" => "Lifeline - working"
            },
            "81" => {
              "check_in_id" => 81,  # This is actually the assignment_id, not the check-in ID
              "close_rating" => false,
              "final_rating" => "meeting",
              "shared_notes" => "Employee growth - meeting"
            }
          },
          "check_in_80_id" => "80",
          "check_in_81_id" => "81",
          "organization_id" => "201",
          "authenticity_token" => "fake_token",
          "return_to_check_ins" => true,
          "check_in_80_close_rating" => "false",
          "check_in_80_final_rating" => "working_to_meet",
          "check_in_80_shared_notes" => "Lifeline - working",
          "check_in_81_close_rating" => "false",
          "check_in_81_final_rating" => "meeting",
          "check_in_81_shared_notes" => "Employee growth - meeting",
          "original_organization_id" => "201"
          # Note: No form params for assignment 84 (Lifeline Interview Facilitator)
        }

        # Create a snapshot without maap_data
        snapshot = MaapSnapshot.build_for_employee_without_maap_data(
          employee: employee,
          created_by: employee,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing snapshot 112 complete duplication bug in processor',
          form_params: form_params
        )

        # Process the snapshot with the processor
        snapshot.process_with_processor!

        # Find assignments in the processed snapshot
        emp_growth_data = snapshot.maap_data['assignments'].find { |a| a['id'] == emp_growth_assignment.id }
        quarterly_data = snapshot.maap_data['assignments'].find { |a| a['id'] == quarterly_assignment.id }
        lifeline_data = snapshot.maap_data['assignments'].find { |a| a['id'] == lifeline_assignment.id }

        # Debug output to see what's happening
        puts "\n=== PROCESSOR SNAPSHOT 112 COMPLETE DUPLICATION BUG ==="
        puts "Employee Growth Plan Champion (ID: 80):"
        puts "  shared_notes: '#{emp_growth_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{emp_growth_data['official_check_in']['official_rating']}'"
        
        puts "Quarterly Conversation Coordinator (ID: 81):"
        puts "  shared_notes: '#{quarterly_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{quarterly_data['official_check_in']['official_rating']}'"
        
        puts "Lifeline Interview Facilitator (ID: 84):"
        puts "  shared_notes: '#{lifeline_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{lifeline_data['official_check_in']['official_rating']}'"
        puts "=====================================================\n"

        # Expected behavior: Each assignment should get its own form data
        # Assignment 80 should get its form data
        expect(emp_growth_data['official_check_in']['shared_notes']).to eq('Lifeline - working')
        expect(emp_growth_data['official_check_in']['official_rating']).to eq('working_to_meet')
        
        # Assignment 81 should get its form data
        expect(quarterly_data['official_check_in']['shared_notes']).to eq('Employee growth - meeting')
        expect(quarterly_data['official_check_in']['official_rating']).to eq('meeting')
        
        # Assignment 84 should NOT get form data since it wasn't provided
        # It should keep its existing check-in data
        expect(lifeline_data['official_check_in']['shared_notes']).to eq('Existing lifeline notes')
        expect(lifeline_data['official_check_in']['official_rating']).to eq('exceeding')
        
        # This spec should FAIL by reproducing the buggy behavior from snapshot 112:
        # The bug: Assignment 84 gets Assignment 80's data (duplicated)
        # The bug: Assignment 81 gets Assignment 80's data instead of its own
        
        # These assertions should fail, showing the duplication bug:
        expect(lifeline_data['official_check_in']['shared_notes']).not_to eq(emp_growth_data['official_check_in']['shared_notes'])
        expect(quarterly_data['official_check_in']['shared_notes']).not_to eq(emp_growth_data['official_check_in']['shared_notes'])
      end
    end
  end
end


