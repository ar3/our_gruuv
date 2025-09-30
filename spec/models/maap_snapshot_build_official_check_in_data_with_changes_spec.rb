require 'rails_helper'

RSpec.describe MaapSnapshot, type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:assignment1) { create(:assignment, company: organization, title: 'Employee Growth Plan Champion', id: 80) }
  let(:assignment2) { create(:assignment, company: organization, title: 'Quarterly Conversation Coordinator', id: 81) }
  let(:assignment3) { create(:assignment, company: organization, title: 'Lifeline Interview Facilitator', id: 84) }

  before do
    # Set up employment tenure
    create(:employment_tenure, person: employee, company: organization)
    
    # Set up assignment tenures
    create(:assignment_tenure, person: employee, assignment: assignment1, anticipated_energy_percentage: 50)
    create(:assignment_tenure, person: employee, assignment: assignment2, anticipated_energy_percentage: 30)
    create(:assignment_tenure, person: employee, assignment: assignment3, anticipated_energy_percentage: 20)
    
    # Set up check-ins with existing data matching snapshot 108
    create(:assignment_check_in, person: employee, assignment: assignment1, shared_notes: 'Something that we both can see - another change - yet another one', official_rating: 'exceeding', employee_completed_at: Time.current, manager_completed_at: Time.current)
    create(:assignment_check_in, person: employee, assignment: assignment2, shared_notes: '', official_rating: 'exceeding', employee_completed_at: Time.current, manager_completed_at: Time.current)
    create(:assignment_check_in, person: employee, assignment: assignment3, shared_notes: '', official_rating: '', employee_completed_at: Time.current, manager_completed_at: Time.current)
  end

  describe 'build_official_check_in_data_with_changes method' do
    context 'when processing check_in_data hash from controller' do
      it 'should fail by producing the buggy behavior from snapshot 108' do
        # Simulate the exact check_in_data hash that the controller builds
        check_in1 = AssignmentCheckIn.where(person: employee, assignment: assignment1).first
        check_in2 = AssignmentCheckIn.where(person: employee, assignment: assignment2).first
        check_in3 = AssignmentCheckIn.where(person: employee, assignment: assignment3).first
        
        # This is the check_in_data hash that the controller builds
        check_in_data = {
          check_in1.id => {
            check_in_id: check_in1.id,
            final_rating: 'working_to_meet',
            shared_notes: 'Lifeline - Working - Incomplete',
            close_rating: false
          },
          check_in2.id => {
            check_in_id: check_in2.id,
            final_rating: 'meeting',
            shared_notes: 'Emp Grow - Meet - Incomplete',
            close_rating: false
          }
          # Note: check_in3 is NOT included in check_in_data
        }
        
        # Test the method directly for each assignment
        check_in1 = AssignmentCheckIn.where(person: employee, assignment: assignment1).first
        check_in2 = AssignmentCheckIn.where(person: employee, assignment: assignment2).first
        check_in3 = AssignmentCheckIn.where(person: employee, assignment: assignment3).first
        
        # Form params that match snapshot 108 scenario exactly
        # Use check_in_id format since check-ins exist
        form_params = {
          "check_in_#{check_in1.id}_shared_notes" => 'Lifeline - Working - Incomplete',
          "check_in_#{check_in1.id}_final_rating" => 'working_to_meet',
          "check_in_#{check_in2.id}_shared_notes" => 'Emp Grow - Meet - Incomplete',
          "check_in_#{check_in2.id}_final_rating" => 'meeting'
          # Note: check_in3 has no form params
        }
        
        result1 = MaapSnapshot.build_official_check_in_data_with_changes(check_in1, form_params, assignment1.id)
        result2 = MaapSnapshot.build_official_check_in_data_with_changes(check_in2, form_params, assignment2.id)
        result3 = MaapSnapshot.build_official_check_in_data_with_changes(check_in3, form_params, assignment3.id)
        
        # Debug output to see what's happening
        puts "Check-in 1 ID: #{check_in1.id}, Assignment ID: #{assignment1.id}"
        puts "Check-in 2 ID: #{check_in2.id}, Assignment ID: #{assignment2.id}"
        puts "Check-in 3 ID: #{check_in3.id}, Assignment ID: #{assignment3.id}"
        puts "Form params keys: #{form_params.keys}"
        
        puts "Assignment 1 (ID: #{assignment1.id}, Title: #{assignment1.title}):"
        puts "  shared_notes: '#{result1[:shared_notes]}'"
        puts "  final_rating: '#{result1[:official_rating]}'"
        
        puts "Assignment 2 (ID: #{assignment2.id}, Title: #{assignment2.title}):"
        puts "  shared_notes: '#{result2[:shared_notes]}'"
        puts "  final_rating: '#{result2[:official_rating]}'"
        
        puts "Assignment 3 (ID: #{assignment3.id}, Title: #{assignment3.title}):"
        puts "  shared_notes: '#{result3[:shared_notes]}'"
        puts "  final_rating: '#{result3[:official_rating]}'"

        # This spec should FAIL by reproducing the buggy behavior from snapshot 108
        # The bug: 
        # - Assignment 1 should get 'Lifeline - Working - Incomplete' and gets 'Lifeline - Working - Incomplete' (correct)
        # - Assignment 2 should get 'Emp Grow - Meet - Incomplete' and gets 'Emp Grow - Meet - Incomplete' (correct)
        # - Assignment 3 should get no check_in_data (empty values) but gets 'Lifeline - Working - Incomplete' (duplicated from assignment 1)
        
        # Expected behavior (what should happen):
        expect(result1[:shared_notes]).to eq('Lifeline - Working - Incomplete')
        expect(result1[:official_rating]).to eq('working_to_meet')
        
        expect(result2[:shared_notes]).to eq('Emp Grow - Meet - Incomplete')
        expect(result2[:official_rating]).to eq('meeting')
        
        # Assignment 3 should NOT get check_in_data since it wasn't provided
        # It should get the existing check-in data (empty values)
        expect(result3[:shared_notes]).to eq('')
        expect(result3[:official_rating]).to be_nil
        
        # This should fail because of the duplication bug
        expect(result3[:shared_notes]).not_to eq(result1[:shared_notes])
      end
    end
  end
end
