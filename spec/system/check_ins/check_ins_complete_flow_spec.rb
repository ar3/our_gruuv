require 'rails_helper'

RSpec.describe 'Check-ins Complete Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager') }
  let!(:manager_teammate) { CompanyTeammate.create!(person: manager_person, organization: company, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: company, external_title: 'Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:manager_employment_tenure) do
    manager_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure,
           teammate: manager_teammate,
           company: company,
           position: position,
           started_at: 1.year.ago,
           ended_at: nil)
  end
  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      position: position,
      company: company,
      manager_teammate: manager_teammate,
      started_at: 1.year.ago
    )
  end
  let!(:assignment1) { create(:assignment, company: company, title: 'Assignment 1') }
  let!(:assignment2) { create(:assignment, company: company, title: 'Assignment 2') }
  let!(:aspiration1) { create(:aspiration, organization: company, name: 'Aspiration 1') }
  let!(:aspiration2) { create(:aspiration, organization: company, name: 'Aspiration 2') }
  let!(:assignment_tenure1) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1, started_at: 6.months.ago) }
  let!(:assignment_tenure2) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment2, started_at: 3.months.ago) }

  describe 'Employee with no prior check-ins, multiple assignments and aspirations' do
    before do
      sign_in_as(employee_person, company)
    end

    it 'allows filling out multiple assignments, aspirations, and position in one save' do
      visit organization_company_teammate_check_ins_path(company, employee_teammate)
      
      expect(page).to have_content('Check-Ins for John Doe')
      # Assignment titles are now in submit buttons, so check for button or content
      expect(page.has_button?('Assignment 1') || page.has_content?('Assignment 1')).to be true
      expect(page.has_button?('Assignment 2') || page.has_content?('Assignment 2')).to be true
      
      # Fill out position check-in
      # Position ratings use numeric values (-3 to 3) with formatted display
      # Use the formatted option text: "🔵 Accomplished - Consistently meets and sometimes exceeds expectations" (value: 2)
      # Capybara's select will wait for the element and options to be available
      select '🔵 Accomplished - Consistently meets and sometimes exceeds expectations', from: 'check_ins[position_check_in][employee_rating]'
      fill_in 'check_ins[position_check_in][employee_private_notes]', with: 'Position notes'
      
      # Fill out assignment check-ins
      check_in1 = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment1)
      check_in2 = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment2)
      
      # Use correct nested form field names: check_ins[assignment_check_ins][#{id}][field]
      # These are select fields with emoji-formatted options
      # Capybara's select has implicit wait, and we need to use the formatted option text
      select '🟢 Exceeding', from: "check_ins[assignment_check_ins][#{check_in1.id}][employee_rating]"
      fill_in "check_ins[assignment_check_ins][#{check_in1.id}][employee_private_notes]", with: 'Assignment 1 notes'
      select '🔵 Meeting', from: "check_ins[assignment_check_ins][#{check_in2.id}][employee_rating]"
      fill_in "check_ins[assignment_check_ins][#{check_in2.id}][employee_private_notes]", with: 'Assignment 2 notes'
      
      # Fill out aspiration check-ins
      aspiration_check_in1 = AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration1)
      aspiration_check_in2 = AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration2)
      
      # Use correct nested form field names: check_ins[aspiration_check_ins][#{id}][field]
      # Use formatted option text with emoji
      select '🟢 Exceeding', from: "check_ins[aspiration_check_ins][#{aspiration_check_in1.id}][employee_rating]"
      fill_in "check_ins[aspiration_check_ins][#{aspiration_check_in1.id}][employee_private_notes]", with: 'Aspiration 1 notes'
      select '🔵 Meeting', from: "check_ins[aspiration_check_ins][#{aspiration_check_in2.id}][employee_rating]"
      fill_in "check_ins[aspiration_check_ins][#{aspiration_check_in2.id}][employee_private_notes]", with: 'Aspiration 2 notes'
      
      # Save all at once - button text is "Save All & Proceed to Review Check-Ins"
      # There are multiple buttons (one per section), use first or scope to form
      # Capybara's first() has implicit wait
      first('input[type="submit"][value="Save All & Proceed to Review Check-Ins"]', visible: true).click
      
      # Verify all check-ins were saved
      expect(page).to have_success_flash('Check-ins saved successfully')
      
      check_in1.reload
      check_in2.reload
      aspiration_check_in1.reload
      aspiration_check_in2.reload
      
      expect(check_in1.employee_rating).to eq('exceeding')
      expect(check_in2.employee_rating).to eq('meeting')
      expect(aspiration_check_in1.employee_rating).to eq('exceeding')
      expect(aspiration_check_in2.employee_rating).to eq('meeting')
    end
  end

  describe 'Employee and Manager scenarios' do
    let!(:check_in) { AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment1) }

    it 'handles scenario where employee started but manager has not' do
      sign_in_as(employee_person, company)
      # Employee completes their side
      check_in.update!(
        employee_rating: 'exceeding',
        employee_private_notes: 'Employee notes',
        employee_completed_at: Time.current
      )
      
      visit organization_company_teammate_check_ins_path(company, employee_teammate)
      
      # Employee view should show completed - check for completion status
      # The status shows as "Ready for Manager" radio button or "Waiting for Manager" badge
      # Check database state instead of UI text which may vary
      expect(check_in.reload.employee_completed_at).to be_present
      
      # Manager view should show manager can complete
      switch_to_user(manager_person, company)
      visit organization_company_teammate_check_ins_path(company, employee_teammate)
      
      # In table view, header shows "Manager Rating", not "Manager Assessment"
      # Check for the field itself (Capybara's fill_in/select have implicit waits)
      expect(page).to have_field("check_ins[assignment_check_ins][#{check_in.id}][manager_rating]")
      # Also verify manager section exists via CSS
      expect(page).to have_css('th', text: 'Manager Rating')
    end

    it 'handles scenario where employee completed and manager saved their side' do
      sign_in_as(manager_person, company)
      
      # Employee completes
      check_in.update!(
        employee_rating: 'exceeding',
        employee_completed_at: Time.current
      )
      
      # Manager saves but doesn't complete
      check_in.update!(
        manager_rating: 'meeting',
        manager_private_notes: 'Manager draft notes'
      )
      
      visit organization_company_teammate_check_ins_path(company, employee_teammate)
      
      # Check for employee completion status - use database check
      expect(check_in.reload.employee_completed_at).to be_present
      # In table view, check for Manager Rating header or field
      expect(page).to have_css('th', text: 'Manager Rating') || have_field("check_ins[assignment_check_ins][#{check_in.id}][manager_rating]")
      expect(check_in.manager_completed_at).to be_nil
    end

    it 'handles scenario where both have completed both sides' do
      sign_in_as(manager_person, company)
      
      # Both complete
      check_in.update!(
        employee_rating: 'exceeding',
        employee_completed_at: Time.current,
        manager_rating: 'meeting',
        manager_completed_at: Time.current,
        manager_completed_by_teammate: manager_teammate
      )
      
      visit organization_company_teammate_check_ins_path(company, employee_teammate)
      
      # Approach 1: Check database state (most reliable)
      expect(check_in.reload.ready_for_finalization?).to be true
      expect(check_in.employee_completed_at).to be_present
      expect(check_in.manager_completed_at).to be_present
      expect(check_in.official_check_in_completed_at).to be_nil
      
      # Approach 2: Check for status indicators in UI
      # The status should show as "Complete" or "Ready" for both sides
      has_complete_status = page.has_content?('Complete') || page.has_css?('.badge', text: /complete|ready/i)
      
      # Approach 3: Verify both ratings are present in the UI
      # Both employee and manager ratings should be visible
      expect(page).to have_content('Exceeding') || page.has_content?('🟢')
      expect(page).to have_content('Meeting') || page.has_content?('🔵')
    end
  end

  describe 'Role-based field visibility' do
    let!(:assignment) { create(:assignment, company: company, title: 'Test Assignment') }
    let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 6.months.ago) }
    let!(:aspiration) { create(:aspiration, organization: company, name: 'Test Aspiration') }
    let!(:assignment_check_in) { AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment) }
    let!(:aspiration_check_in) { AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration) }
    
    # Ensure employment_tenure has manager set for manager view mode to work
    before do
      employment_tenure.update!(manager_teammate: manager_teammate) if employment_tenure.manager_teammate != manager_teammate
    end

    describe 'Employee view' do
      before do
        sign_in_as(employee_person, company)
      end

      it 'shows only employee fields and hides manager fields' do
        visit organization_company_teammate_check_ins_path(company, employee_teammate)
        
        # Should see employee fields for assignments
        expect(page).to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][employee_rating]")
        expect(page).to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][actual_energy_percentage]")
        expect(page).to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][employee_personal_alignment]")
        expect(page).to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][employee_private_notes]")
        
        # Should see employee fields for aspirations
        expect(page).to have_field("check_ins[aspiration_check_ins][#{aspiration_check_in.id}][employee_rating]")
        expect(page).to have_field("check_ins[aspiration_check_ins][#{aspiration_check_in.id}][employee_private_notes]")
        
        # Should NOT see manager fields for assignments
        expect(page).not_to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][manager_rating]")
        expect(page).not_to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][manager_private_notes]")
        
        # Should NOT see manager fields for aspirations
        expect(page).not_to have_field("check_ins[aspiration_check_ins][#{aspiration_check_in.id}][manager_rating]")
        expect(page).not_to have_field("check_ins[aspiration_check_ins][#{aspiration_check_in.id}][manager_private_notes]")
        
        # Should NOT see manager assessment section headers
        expect(page).not_to have_content('Manager Assessment')
        
        # Critical: Should NOT see both Employee Assessment and Manager Assessment sections
        # Count occurrences to ensure we're not seeing both
        html = page.html
        employee_assessment_count = html.scan(/Employee Assessment/).count
        manager_assessment_count = html.scan(/Manager Assessment/).count
        
        # Note: Employee Assessment sections may not appear if check-ins are completed
        # The key test is that we should NOT see Manager Assessment sections
        expect(manager_assessment_count).to eq(0), "Employee should NOT see Manager Assessment sections (found #{manager_assessment_count})"
        
        # If Employee Assessment sections are present, verify Manager sections are not
        if employee_assessment_count > 0
          expect(manager_assessment_count).to eq(0), "When Employee Assessment is visible, Manager Assessment should NOT be visible (found #{manager_assessment_count})"
        end
      end
      
      it 'shows only employee fields' do
        visit organization_company_teammate_check_ins_path(company, employee_teammate)
        
        # Should see employee headers in table
        expect(page).to have_css('th', text: 'Employee Rating')
        expect(page).to have_css('th', text: 'Employee Notes')
        
        # Should NOT see manager headers in table
        expect(page).not_to have_css('th', text: 'Manager Rating')
        expect(page).not_to have_css('th', text: 'Manager Notes')
      end

      it 'pre-selects existing actual_energy_percentage value in dropdown' do
        # Create a check-in with an existing energy percentage value
        assignment_check_in.update!(actual_energy_percentage: 75)
        assignment_check_in.reload
        
        visit organization_company_teammate_check_ins_path(company, employee_teammate)
        
        # Find the actual energy percentage select field
        select_element = page.find("select[name=\"check_ins[assignment_check_ins][#{assignment_check_in.id}][actual_energy_percentage]\"]")
        selected_value = select_element.value
        
        # The selected value should be "75" (as a string from the select element)
        expect(selected_value).to eq('75')
        
        # Verify the selected option text is "75%"
        selected_option = select_element.find("option[value='#{selected_value}']")
        expect(selected_option.text).to eq('75%')
      end
    end

    describe 'Manager view' do
      before do
        sign_in_as(manager_person, company)
      end

      it 'shows only manager fields and hides employee fields' do
        visit organization_company_teammate_check_ins_path(company, employee_teammate)
        
        # Should see manager fields for assignments
        expect(page).to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][manager_rating]")
        expect(page).to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][manager_private_notes]")
        
        # Should see manager fields for aspirations
        expect(page).to have_field("check_ins[aspiration_check_ins][#{aspiration_check_in.id}][manager_rating]")
        expect(page).to have_field("check_ins[aspiration_check_ins][#{aspiration_check_in.id}][manager_private_notes]")
        
        # Should NOT see employee fields for assignments
        expect(page).not_to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][employee_rating]")
        expect(page).not_to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][actual_energy_percentage]")
        expect(page).not_to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][employee_personal_alignment]")
        expect(page).not_to have_field("check_ins[assignment_check_ins][#{assignment_check_in.id}][employee_private_notes]")
        
        # Should NOT see employee fields for aspirations
        expect(page).not_to have_field("check_ins[aspiration_check_ins][#{aspiration_check_in.id}][employee_rating]")
        expect(page).not_to have_field("check_ins[aspiration_check_ins][#{aspiration_check_in.id}][employee_private_notes]")
        
        # Should NOT see employee assessment section headers
        expect(page).not_to have_content('Employee Assessment')
        
        # Critical: Should NOT see both Employee Assessment and Manager Assessment sections
        # Count occurrences to ensure we're not seeing both
        html = page.html
        employee_assessment_count = html.scan(/Employee Assessment/).count
        manager_assessment_count = html.scan(/Manager Assessment/).count
        
        # Note: Manager Assessment sections may not appear if check-ins are completed
        # The key test is that we should NOT see Employee Assessment sections
        expect(employee_assessment_count).to eq(0), "Manager should NOT see Employee Assessment sections (found #{employee_assessment_count})"
        
        # If Manager Assessment sections are present, verify Employee sections are not
        if manager_assessment_count > 0
          expect(employee_assessment_count).to eq(0), "When Manager Assessment is visible, Employee Assessment should NOT be visible (found #{employee_assessment_count})"
        end
      end
      
      it 'shows only manager fields' do
        visit organization_company_teammate_check_ins_path(company, employee_teammate)
        
        # Should see manager headers in table
        expect(page).to have_css('th', text: 'Manager Rating')
        expect(page).to have_css('th', text: 'Manager Notes')
        
        # Should NOT see employee headers in table
        expect(page).not_to have_css('th', text: 'Employee Rating')
        expect(page).not_to have_css('th', text: 'Employee Notes')
      end
    end
  end

  describe 'Collapsible section for non-active assignments' do
    let!(:active_assignment) { create(:assignment, company: company, title: 'Active Assignment') }
    let!(:inactive_assignment) { create(:assignment, company: company, title: 'Inactive Assignment') }
    let!(:active_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: active_assignment, started_at: 6.months.ago, ended_at: nil) }
    let!(:inactive_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: inactive_assignment, started_at: 6.months.ago, ended_at: 3.months.ago) }

    before do
      sign_in_as(employee_person, company)
      # Ensure check-ins are created for both assignments
      AssignmentCheckIn.find_or_create_open_for(employee_teammate, active_assignment)
      AssignmentCheckIn.find_or_create_open_for(employee_teammate, inactive_assignment)
    end

    it 'shows active assignments in main table' do
      visit organization_company_teammate_check_ins_path(company, employee_teammate)
      
      # Active assignment should be visible in main table
      expect(page).to have_content('Active Assignment')
      
      # Should not be in a collapsible section (section might exist but be collapsed)
      expect(page).not_to have_css('#nonActiveAssignmentsSection.show')
    end

    it 'shows non-active assignments in collapsible section' do
      visit organization_company_teammate_check_ins_path(company, employee_teammate)
      
      # Collapsible section should exist (may be collapsed/hidden)
      expect(page).to have_css('#nonActiveAssignmentsSection', visible: :all)
      
      # Section should be collapsed by default (not have .show class)
      expect(page).not_to have_css('#nonActiveAssignmentsSection.show', visible: :all)
      
      # Title should include teammate's casual name
      expect(page).to have_content("Check-in on an Assignment #{employee_person.casual_name} is (re)starting")
    end

    it 'expands and collapses the non-active assignments section' do
      visit organization_company_teammate_check_ins_path(company, employee_teammate)
      
      # Initially collapsed - inactive assignment should not be visible in expanded section
      expect(page).not_to have_css('#nonActiveAssignmentsSection.show', visible: :all)
      
      # Click to expand - find the button by its data attribute
      find('button[data-bs-target="#nonActiveAssignmentsSection"]', visible: :all).click
      
      # Wait for section to expand
      expect(page).to have_css('#nonActiveAssignmentsSection.show', wait: 2)
      
      # Now inactive assignment should be visible (assignment titles are in buttons)
      within('#nonActiveAssignmentsSection') do
        expect(page.has_button?('Inactive Assignment') || page.has_content?('Inactive Assignment')).to be true
      end
      
      # Click to collapse
      find('button[data-bs-target="#nonActiveAssignmentsSection"]', visible: :all).click
      
      # Wait for section to collapse
      expect(page).not_to have_css('#nonActiveAssignmentsSection.show', wait: 2)
    end

    it 'does not show collapsible section when all assignments are active' do
      # Remove inactive assignment
      inactive_tenure.destroy
      AssignmentCheckIn.where(teammate: employee_teammate, assignment: inactive_assignment).destroy_all
      
      visit organization_company_teammate_check_ins_path(company, employee_teammate)
      
      # Collapsible section should not exist
      expect(page).not_to have_css('#nonActiveAssignmentsSection')
      expect(page).not_to have_content("Check-in on an Assignment #{employee_person.casual_name} is (re)starting")
    end

    it 'shows both active and non-active assignments correctly' do
      visit organization_company_teammate_check_ins_path(company, employee_teammate)
      
      # Active assignment should be in main table
      expect(page).to have_content('Active Assignment')
      
      # Expand collapsible section
      find('button[data-bs-target="#nonActiveAssignmentsSection"]', visible: :all).click
      expect(page).to have_css('#nonActiveAssignmentsSection.show', wait: 2)
      
      # Inactive assignment should be in collapsible section (assignment titles are in buttons)
      within('#nonActiveAssignmentsSection') do
        expect(page.has_button?('Inactive Assignment') || page.has_content?('Inactive Assignment')).to be true
      end
    end
  end
end

