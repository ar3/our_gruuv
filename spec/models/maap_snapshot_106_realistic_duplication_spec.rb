require 'rails_helper'

RSpec.describe MaapSnapshot, type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment1) { create(:assignment, company: organization, title: 'Employee Growth Plan Champion', id: 80) }
  let(:assignment2) { create(:assignment, company: organization, title: 'Quarterly Conversation Coordinator', id: 81) }

  before do
    # Set up employment tenure
    create(:employment_tenure, teammate: employee_teammate, company: organization)
    
    # Set up assignment tenures
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1, anticipated_energy_percentage: 50)
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment2, anticipated_energy_percentage: 30)
    
    # Set up check-ins with existing shared_notes (like in snapshot 106)
    create(:assignment_check_in, teammate: employee_teammate, assignment: assignment1, shared_notes: 'emp grow - not set')
    create(:assignment_check_in, teammate: employee_teammate, assignment: assignment2, shared_notes: 'emp grow - not set')
  end

  describe 'build_official_check_in_data_with_changes' do
    context 'when check-ins have existing shared_notes and form params provide different values' do
      it 'should not duplicate shared_notes and ratings across assignments' do
        # Form params that match snapshot 106 scenario exactly
        form_params = {
          "check_in_80_shared_notes" => 'Lifeline - working',
          "check_in_80_final_rating" => 'working_to_meet',
          "check_in_81_shared_notes" => 'emp grow - not set',
          "check_in_81_final_rating" => 'working_to_meet'
        }

        # Create MAAP snapshot
        snapshot = MaapSnapshot.build_for_employee_with_changes(
          employee: employee,
          created_by: employee,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing snapshot 106 realistic duplication scenario',
          form_params: form_params
        )

        # Find assignments in the snapshot
        assignment1_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        assignment2_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment2.id }

        # Debug output to see what's happening
        puts "Assignment 1 (ID: #{assignment1.id}, Title: #{assignment1.title}):"
        puts "  shared_notes: '#{assignment1_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{assignment1_data['official_check_in']['official_rating']}'"
        
        puts "Assignment 2 (ID: #{assignment2.id}, Title: #{assignment2.title}):"
        puts "  shared_notes: '#{assignment2_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{assignment2_data['official_check_in']['official_rating']}'"

        # These should fail - reproducing the exact duplication from snapshot 106
        # Assignment 1 should have 'Lifeline - working' but gets 'emp grow - not set' (duplicated)
        # Assignment 2 should have 'emp grow - not set' and gets 'emp grow - not set' (correct)
        expect(assignment1_data['official_check_in']['shared_notes']).to eq('Lifeline - working')
        expect(assignment1_data['official_check_in']['official_rating']).to eq('working_to_meet')
        
        expect(assignment2_data['official_check_in']['shared_notes']).to eq('emp grow - not set')
        expect(assignment2_data['official_check_in']['official_rating']).to eq('working_to_meet')
        
        # Verify no duplication - values should be different
        expect(assignment1_data['official_check_in']['shared_notes']).not_to eq(assignment2_data['official_check_in']['shared_notes'])
      end
    end
  end
end


