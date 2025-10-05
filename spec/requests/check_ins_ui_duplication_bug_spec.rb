require 'rails_helper'

RSpec.describe 'Check-ins UI Duplication Bug', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment1) { create(:assignment, company: organization, title: 'Employee Growth Plan Champion', id: 80) }
  let(:assignment2) { create(:assignment, company: organization, title: 'Quarterly Conversation Coordinator', id: 81) }
  let(:assignment3) { create(:assignment, company: organization, title: 'Lifeline Interview Facilitator', id: 84) }

  before do
    # Set up employment tenure
    create(:employment_tenure, teammate: manager_teammate, company: organization)
    create(:employment_tenure, teammate: employee_teammate, company: organization)
    
    # Set up assignment tenures
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1, anticipated_energy_percentage: 50)
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment2, anticipated_energy_percentage: 30)
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment3, anticipated_energy_percentage: 20)
    
    # Set up check-ins with existing data and completion timestamps
    create(:assignment_check_in, teammate: employee_teammate, assignment: assignment1, shared_notes: 'Something that we both can see - another change - yet another one', official_rating: 'exceeding', employee_completed_at: Time.current, manager_completed_at: Time.current)
    create(:assignment_check_in, teammate: employee_teammate, assignment: assignment2, shared_notes: '', official_rating: 'exceeding', employee_completed_at: Time.current, manager_completed_at: Time.current)
    create(:assignment_check_in, teammate: employee_teammate, assignment: assignment3, shared_notes: '', official_rating: '', employee_completed_at: Time.current, manager_completed_at: Time.current)
    
    # Set up authorization
    manager_teammate.update!(can_manage_employment: true)
    
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_person!)
  end

  describe 'bulk check-in finalization form submission' do
    it 'should fail by reproducing the cross-assignment duplication bug' do
      # Simulate the exact form submission from the UI scenario
      # User updates:
      # - Lifeline Interview Facilitator (assignment 84): "Working to meet" + "Lifeline - Working - Incomplete"
      # - Employee Growth Plan Champion (assignment 80): "Meeting" + "Emp Grow - Meet - Incomplete"
      # - Quarterly Conversation Coordinator (assignment 81): no changes
      
      # Get the check-in IDs for the form params
      check_in1 = AssignmentCheckIn.where(teammate: employee_teammate, assignment: assignment1).first
      check_in2 = AssignmentCheckIn.where(teammate: employee_teammate, assignment: assignment2).first
      check_in3 = AssignmentCheckIn.where(teammate: employee_teammate, assignment: assignment3).first
      
      # Form params as they would be submitted from the UI
      params = {
        organization_id: organization.id,
        id: employee.id,
        "check_in_#{check_in3.id}_shared_notes" => 'Lifeline - Working - Incomplete',
        "check_in_#{check_in3.id}_final_rating" => 'working_to_meet',
        "check_in_#{check_in1.id}_shared_notes" => 'Emp Grow - Meet - Incomplete',
        "check_in_#{check_in1.id}_final_rating" => 'meeting'
        # Note: check_in2 has no form params
      }

      # Make the request with session
      patch bulk_finalize_check_ins_organization_check_in_path(organization, employee), params: params
      
      # Debug output
      puts "Response status: #{response.status}"
      puts "Response location: #{response.location}"
      puts "Flash messages: #{flash.inspect}"
      puts "MaapSnapshot count: #{MaapSnapshot.count}"

      # Check response
      expect(response).to have_http_status(:redirect)
      
      # Get the created snapshot
      snapshot = MaapSnapshot.last
      expect(snapshot).to be_present
      
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

      # This spec should FAIL by reproducing the buggy behavior from the UI
      # The bug: 
      # - Assignment 1 (Employee Growth Plan Champion) should get 'Emp Grow - Meet - Incomplete' but gets 'Lifeline - Working - Incomplete' (wrong)
      # - Assignment 2 (Quarterly Conversation Coordinator) should get no changes but gets 'Emp Grow - Meet - Incomplete' (wrong)
      # - Assignment 3 (Lifeline Interview Facilitator) should get 'Lifeline - Working - Incomplete' and gets 'Lifeline - Working - Incomplete' (correct)
      
      # Expected behavior (what should happen):
      expect(assignment1_data['official_check_in']['shared_notes']).to eq('Emp Grow - Meet - Incomplete')
      expect(assignment1_data['official_check_in']['official_rating']).to eq('meeting')
      
      expect(assignment2_data['official_check_in']['shared_notes']).not_to eq('Emp Grow - Meet - Incomplete')
      expect(assignment2_data['official_check_in']['shared_notes']).not_to eq('Lifeline - Working - Incomplete')
      
      expect(assignment3_data['official_check_in']['shared_notes']).to eq('Lifeline - Working - Incomplete')
      expect(assignment3_data['official_check_in']['official_rating']).to eq('working_to_meet')
      
      # These should fail because of the duplication bug
      expect(assignment1_data['official_check_in']['shared_notes']).not_to eq(assignment3_data['official_check_in']['shared_notes'])
      expect(assignment2_data['official_check_in']['shared_notes']).not_to eq(assignment1_data['official_check_in']['shared_notes'])
    end
  end
end
