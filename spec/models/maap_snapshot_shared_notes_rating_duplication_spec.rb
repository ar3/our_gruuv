require 'rails_helper'

RSpec.describe MaapSnapshot, type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:assignment1) { create(:assignment, company: organization, title: 'Employee Growth Plan Champion') }
  let(:assignment2) { create(:assignment, company: organization, title: 'Quarterly Conversation Coordinator') }
  let(:assignment3) { create(:assignment, company: organization, title: 'Lifeline Interview Facilitator') }

  before do
    # Set up employment tenure
    create(:employment_tenure, person: employee, company: organization)
    
    # Set up assignment tenures
    create(:assignment_tenure, person: employee, assignment: assignment1, anticipated_energy_percentage: 50)
    create(:assignment_tenure, person: employee, assignment: assignment2, anticipated_energy_percentage: 30)
    create(:assignment_tenure, person: employee, assignment: assignment3, anticipated_energy_percentage: 20)
    
    # Set up check-ins
    create(:assignment_check_in, person: employee, assignment: assignment1)
    create(:assignment_check_in, person: employee, assignment: assignment2)
    create(:assignment_check_in, person: employee, assignment: assignment3)
  end

  describe 'build_official_check_in_data_with_changes' do
    context 'when multiple assignments have different form params' do
      it 'should not duplicate shared_notes and ratings across assignments' do
        # Form params with different values for each assignment
        form_params = {
          "check_in_#{assignment1.id}_shared_notes" => 'emp grow - not set',
          "check_in_#{assignment1.id}_final_rating" => 'exceeding',
          "check_in_#{assignment2.id}_shared_notes" => 'quarterly - working',
          "check_in_#{assignment2.id}_final_rating" => 'meeting',
          "check_in_#{assignment3.id}_shared_notes" => 'lifeline - needs improvement',
          "check_in_#{assignment3.id}_final_rating" => 'below_expectations'
        }

        # Create MAAP snapshot
        snapshot = MaapSnapshot.build_for_employee_with_changes(
          employee: employee,
          created_by: employee,
          change_type: 'bulk_check_in_finalization',
          reason: 'Testing shared notes and rating duplication',
          form_params: form_params
        )

        # Find assignments in the snapshot
        assignment1_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        assignment2_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment2.id }
        assignment3_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment3.id }

        # Debug output to see what's happening
        puts "Assignment 1 (#{assignment1.title}):"
        puts "  shared_notes: '#{assignment1_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{assignment1_data['official_check_in']['official_rating']}'"
        
        puts "Assignment 2 (#{assignment2.title}):"
        puts "  shared_notes: '#{assignment2_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{assignment2_data['official_check_in']['official_rating']}'"
        
        puts "Assignment 3 (#{assignment3.title}):"
        puts "  shared_notes: '#{assignment3_data['official_check_in']['shared_notes']}'"
        puts "  final_rating: '#{assignment3_data['official_check_in']['official_rating']}'"

        # These should fail - each assignment should have its own unique values
        expect(assignment1_data['official_check_in']['shared_notes']).to eq('emp grow - not set')
        expect(assignment1_data['official_check_in']['official_rating']).to eq('exceeding')
        
        expect(assignment2_data['official_check_in']['shared_notes']).to eq('quarterly - working')
        expect(assignment2_data['official_check_in']['official_rating']).to eq('meeting')
        
        expect(assignment3_data['official_check_in']['shared_notes']).to eq('lifeline - needs improvement')
        expect(assignment3_data['official_check_in']['official_rating']).to eq('below_expectations')
        
        # Verify no duplication - all values should be unique
        shared_notes_values = [
          assignment1_data['official_check_in']['shared_notes'],
          assignment2_data['official_check_in']['shared_notes'],
          assignment3_data['official_check_in']['shared_notes']
        ]
        expect(shared_notes_values.uniq.length).to eq(3), "Shared notes are being duplicated: #{shared_notes_values}"
        
        rating_values = [
          assignment1_data['official_check_in']['official_rating'],
          assignment2_data['official_check_in']['official_rating'],
          assignment3_data['official_check_in']['official_rating']
        ]
        expect(rating_values.uniq.length).to eq(3), "Ratings are being duplicated: #{rating_values}"
      end
    end
  end
end


