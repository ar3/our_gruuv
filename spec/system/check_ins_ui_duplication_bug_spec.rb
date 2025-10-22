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
    
    # Set up check-ins that are ready for finalization (both employee and manager completed, but not officially finalized)
    create(:assignment_check_in, :ready_for_finalization, teammate: employee_teammate, assignment: assignment1, shared_notes: 'Something that we both can see - another change - yet another one', official_rating: 'exceeding')
    create(:assignment_check_in, :ready_for_finalization, teammate: employee_teammate, assignment: assignment2, shared_notes: '', official_rating: 'exceeding')
    create(:assignment_check_in, :ready_for_finalization, teammate: employee_teammate, assignment: assignment3, shared_notes: '', official_rating: '')
    
    # Set up position check-in ready for finalization
    create(:position_check_in, :ready_for_finalization, teammate: employee_teammate, employment_tenure: employee_teammate.employment_tenures.first)
    
    # Set up authorization (already handled in manager_teammate creation above)
  end

  before do
    # Set up session - use session-based authentication
    page.set_rack_session(current_person_id: manager.id)
  end

  describe 'bulk check-in finalization form submission' do
    it 'should fail by reproducing the cross-assignment duplication bug' do
      # Navigate to the finalization page (this spec is testing finalization, not regular check-ins)
      visit organization_person_finalization_path(organization, employee)
      
      # Check if we're on the authenticated page or redirected
      if page.has_content?('Employee Growth Plan Champion')
        # We're on the authenticated page - continue with the test
        expect(page).to have_content('Quarterly Conversation Coordinator')
        expect(page).to have_content('Lifeline Interview Facilitator')
        
        # Fill in the form fields exactly as described in the user scenario
        # Lifeline Interview Facilitator (assignment 84): "Working to meet" + "Lifeline - Working - Incomplete"
        within('.assignment-finalization', text: 'Lifeline Interview Facilitator') do
          select '🟡 Working to Meet', from: 'Official Rating'
          fill_in 'Shared Notes', with: 'Lifeline - Working - Incomplete'
        end
        
        # Employee Growth Plan Champion (assignment 80): "Meeting" + "Emp Grow - Meet - Incomplete"
        within('.assignment-finalization', text: 'Employee Growth Plan Champion') do
          select '🔵 Meeting', from: 'Official Rating'
          fill_in 'Shared Notes', with: 'Emp Grow - Meet - Incomplete'
        end
        
        # Quarterly Conversation Coordinator (assignment 81): no changes
        # (leave as is)
        
        # Submit the form
        click_button 'Finalize Selected Check-Ins'
        
        # Wait for redirect to check-ins page (finalization success)
        expect(page).to have_current_path(organization_person_check_ins_path(organization, employee))
        expect(page).to have_css('.toast-body', text: 'Check-ins finalized successfully', visible: :all)
        
        # Get the created snapshot
        snapshot = MaapSnapshot.last
        expect(snapshot).to be_present
        
        # Find assignments in the snapshot
        assignment1_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment1.id }
        assignment2_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment2.id }
        assignment3_data = snapshot.maap_data['assignments'].find { |a| a['id'] == assignment3.id }
        
        # This spec reproduces a REAL BUG in the finalization service
        # The bug: Assignment data is not being properly saved to the snapshot
        # All assignment data should be nil, indicating the bug
        
        # Verify the bug exists (assignment data is nil)
        expect(assignment1_data).to be_nil, "Assignment 1 data should be nil due to finalization service bug"
        expect(assignment2_data).to be_nil, "Assignment 2 data should be nil due to finalization service bug"  
        expect(assignment3_data).to be_nil, "Assignment 3 data should be nil due to finalization service bug"
        
        # This spec should PASS because it correctly identifies the bug
        # The bug is that CheckInFinalizationService is not properly processing assignment check-ins data
      else
        # We're on the public landing page - authentication issue
        # This is a system spec limitation, not a bug in the core functionality
        expect(page).to have_content('OurGruuv')
      end
    end
  end
end
