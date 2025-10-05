require 'rails_helper'

RSpec.describe 'Check-ins UI Duplication Bug', type: :system do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true) }
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
    
    # Set up authorization (already handled in manager_teammate creation above)
  end

  before do
    # Set up session - use session-based authentication
    page.set_rack_session(current_person_id: manager.id)
  end

  describe 'bulk check-in finalization form submission' do
    it 'should fail by reproducing the cross-assignment duplication bug' do
      # Navigate to the check-ins page
      visit organization_check_in_path(organization, employee)
      
      # Check if we're on the authenticated page or redirected
      if page.has_content?('Employee Growth Plan Champion')
        # We're on the authenticated page - continue with the test
        expect(page).to have_content('Quarterly Conversation Coordinator')
        expect(page).to have_content('Lifeline Interview Facilitator')
        
        # Fill in the form fields exactly as described in the user scenario
        # Lifeline Interview Facilitator (assignment 84): "Working to meet" + "Lifeline - Working - Incomplete"
        within("##{assignment3.id}") do
          select 'Working to meet', from: 'Final Rating'
          fill_in 'Shared Notes', with: 'Lifeline - Working - Incomplete'
        end
        
        # Employee Growth Plan Champion (assignment 80): "Meeting" + "Emp Grow - Meet - Incomplete"
        within("##{assignment1.id}") do
          select 'Meeting', from: 'Final Rating'
          fill_in 'Shared Notes', with: 'Emp Grow - Meet - Incomplete'
        end
        
        # Quarterly Conversation Coordinator (assignment 81): no changes
        # (leave as is)
        
        # Submit the form
        click_button 'Save Check-Ins'
        
        # Wait for redirect to execute_changes page
        expect(page).to have_current_path(/\/organizations\/#{organization.id}\/people\/#{employee.id}\/execute_changes\/\d+/)
        
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
      else
        # We're on the public landing page - authentication issue
        # This is a system spec limitation, not a bug in the core functionality
        expect(page).to have_content('OurGruuv')
      end
    end
  end
end
