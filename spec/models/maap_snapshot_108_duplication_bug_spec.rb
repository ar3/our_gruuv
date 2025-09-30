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

  describe 'build_official_check_in_data_with_changes' do
    context 'when form params only include some assignments but snapshot includes all' do
      it 'should fail by reproducing the buggy behavior from snapshot 108' do
        # Form params that match snapshot 108 scenario exactly
        # Only assignments 80 and 81 have form params, but assignment 84 gets duplicated values
        form_params = {
          "check_in_80_shared_notes" => 'Lifeline - Working - Incomplete',
          "check_in_80_final_rating" => 'working_to_meet',
          "check_in_81_shared_notes" => 'Emp Grow - Meet - Incomplete',
          "check_in_81_final_rating" => 'meeting'
          # Note: assignment 84 has no form params
        }

        # Create MAAP snapshot
        snapshot = MaapSnapshot.build_for_employee_with_changes(
          employee: employee,
          created_by: employee,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing snapshot 108 duplication bug',
          form_params: form_params
        )

        # Find assignments in the snapshot
        assignment1_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        assignment2_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment2.id }
        assignment3_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment3.id }

        # Debug output to see what's happening
        puts "Assignment 1 (ID: #{assignment1.id}, Title: #{assignment1.title}):"
        puts "  shared_notes: '#{assignment1_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{assignment1_data['official_check_in']['official_rating']}'"
        
        puts "Assignment 2 (ID: #{assignment2.id}, Title: #{assignment2.title}):"
        puts "  shared_notes: '#{assignment2_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{assignment2_data['official_check_in']['official_rating']}'"
        
        puts "Assignment 3 (ID: #{assignment3.id}, Title: #{assignment3.title}):"
        puts "  shared_notes: '#{assignment3_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{assignment3_data['official_check_in']['official_rating']}'"

        # This spec should FAIL by reproducing the buggy behavior from snapshot 108
        # The bug: 
        # - Assignment 1 should get 'Lifeline - Working - Incomplete' and gets 'Lifeline - Working - Incomplete' (correct)
        # - Assignment 2 should get 'Emp Grow - Meet - Incomplete' and gets 'Emp Grow - Meet - Incomplete' (correct)
        # - Assignment 3 should get no form params (empty values) but gets 'Lifeline - Working - Incomplete' (duplicated from assignment 1)
        
        # Expected behavior (what should happen):
        expect(assignment1_data['official_check_in']['shared_notes']).to eq('Lifeline - Working - Incomplete')
        expect(assignment1_data['official_check_in']['official_rating']).to eq('working_to_meet')
        
        expect(assignment2_data['official_check_in']['shared_notes']).to eq('Emp Grow - Meet - Incomplete')
        expect(assignment2_data['official_check_in']['official_rating']).to eq('meeting')
        
        # Assignment 3 should NOT get form params since they weren't provided
        # It should get the existing check-in data (empty values)
        expect(assignment3_data['official_check_in']['shared_notes']).to eq('')
        expect(assignment3_data['official_check_in']['official_rating']).to be_nil
        
        # This should fail because of the duplication bug
        expect(assignment3_data['official_check_in']['shared_notes']).not_to eq(assignment1_data['official_check_in']['shared_notes'])
      end
    end
  end
end
