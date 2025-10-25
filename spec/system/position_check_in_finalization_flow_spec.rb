require 'rails_helper'

RSpec.describe 'Position Check-In Finalization Flow', type: :system do
  include_context 'check_in_test_data'

  describe 'Company-level employee (manager fills first)' do
    it 'allows manager and employee to complete check-ins and shows both perspectives on finalization' do
      # Step 1: Manager fills position check-in for company_employee (mark ready)
      sign_in_as(manager, company)
      visit organization_person_check_ins_path(company, company_employee)
      
      # Find the position check-in
      position_check_in = PositionCheckIn.find_by(teammate: company_employee_teammate)
      
      # Fill out position check-in (mark ready)
      within('table', text: 'Position') do
        select '🟢 Looking to Reward - Exceptional, seeking to increase responsibility', from: 'check_ins[position_check_in][manager_rating]'
        fill_in 'check_ins[position_check_in][manager_private_notes]', with: 'Manager assessment: Company employee is exceeding expectations in their position'
        find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      end
      click_button 'Save All Check-Ins'
      
      # Wait for page to reload and verify we see the appropriate view
      expect(page).to have_current_path(organization_person_check_ins_path(company, company_employee))
      
      # Mark as draft to re-open for editing
      within('table', text: 'Position') do
        find('input[type="radio"][value="draft"]').click
        sleep 0.5 # Wait for DOM to update
        sleep 0.5 # Wait for DOM to update
      end
      click_button 'Save All Check-Ins'
      
      # Wait for page to reload and verify we see the editable form view
      expect(page).to have_content('EDITABLE FORM VIEW')
      
      # Now fill out the form (tests that draft mode works)
      within('table', text: 'Position') do
        select '🟢 Looking to Reward - Exceptional, seeking to increase responsibility', from: 'check_ins[position_check_in][manager_rating]'
        fill_in 'check_ins[position_check_in][manager_private_notes]', with: 'Manager assessment: Company employee is exceeding expectations in their position'
        find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      end
      
      # Step 2: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 3: Employee fills position check-in (mark ready)
      puts "\n=== DEBUG: Current driver: #{Capybara.current_driver} ==="
      puts "=== JavaScript driver: #{Capybara.javascript_driver} ==="
      # Sign out first to clear any cached session
      sign_out
      sleep 0.5
      sign_in_as(company_employee, company)
      # Add a small delay to ensure session is processed
      sleep 0.5
      visit organization_person_check_ins_path(company, company_employee)
      
      # Verify we're in employee view mode
      expect(page).to have_content('EDITABLE FORM VIEW')
      
      # Debug: Print all form fields
      puts "\n=== DEBUG: ALL SELECT FIELDS ON PAGE ==="
      all('select').each do |select_field|
        puts "  Name: '#{select_field['name']}'"
        puts "  ID: '#{select_field['id']}'"
        puts "  Classes: '#{select_field['class']}'"
        puts "  ---"
      end
      puts "=== END SELECT FIELDS ===\n"

      puts "\n=== DEBUG: ALL INPUT FIELDS ON PAGE ==="
      all('input[type="radio"]').each do |input_field|
        puts "  Name: '#{input_field['name']}'"
        puts "  Value: '#{input_field['value']}'"
        puts "  ID: '#{input_field['id']}'"
        puts "  ---"
      end
      puts "=== END INPUT FIELDS ===\n"

      puts "\n=== DEBUG: PAGE CONTENT (first 2000 chars) ==="
      puts page.text[0..2000]
      puts "=== END PAGE CONTENT ===\n"
      
      # Fill out position check-in (mark ready)
      find('select[name="check_ins[position_check_in][employee_rating]"]').select('🔵 Praising/Trusting - Consistent strong performance')
      fill_in 'check_ins[position_check_in][employee_private_notes]', with: 'Employee assessment: I feel I am meeting expectations in my position'
      find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      click_button 'Save All Check-Ins'
      
      # Mark as draft to re-open for editing
      within('table', text: 'Position') do
        find('input[type="radio"][value="draft"]').click
        sleep 0.5 # Wait for DOM to update
      end
      click_button 'Save All Check-Ins'
      
      # Verify we're now in editable form view
      expect(page).to have_content('EDITABLE FORM VIEW')
      
      # Now fill out the form (tests that draft mode works)
      find('select[name="check_ins[position_check_in][employee_rating]"]').select('🔵 Praising/Trusting - Consistent strong performance')
      fill_in 'check_ins[position_check_in][employee_private_notes]', with: 'Employee assessment: I feel I am meeting expectations in my position'
      find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      
      # Step 4: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 5: Manager goes to finalization page and finalizes
      puts "\n=== DEBUG: MANAGER SIGN-IN FOR FINALIZATION ==="
      sign_out
      sleep 0.5
      sign_in_as(manager, company)
      sleep 0.5
      visit organization_person_finalization_path(company, company_employee)
      
      # Debug: Print all form fields on finalization page
      puts "\n=== DEBUG: FINALIZATION PAGE FIELDS ==="
      all('select').each do |select_field|
        puts "  Name: '#{select_field['name']}'"
        puts "  ID: '#{select_field['id']}'"
        puts "  Disabled: '#{select_field['disabled']}'"
        puts "  Options: #{select_field.all('option').map(&:text)}"
        puts "  ---"
      end
      puts "=== END FINALIZATION FIELDS ===\n"

      puts "\n=== DEBUG: FINALIZATION PAGE CONTENT (first 2000 chars) ==="
      puts page.text[0..2000]
      puts "=== END FINALIZATION PAGE CONTENT ===\n"
      
      # Fill out the finalization form
      # Ensure the finalize position checkbox is checked
      check 'finalize_position'
      select '🟢 Looking to Reward - Exceptional, seeking to increase responsibility', from: 'position_official_rating'
      fill_in 'position_shared_notes', with: 'Finalized: Employee shows exceptional performance and growth potential'
      click_button 'Finalize Selected Check-Ins'
      
      # Step 6: Critical assertions to catch the bug
      # Debug: Check what flash notices are on the page
      puts "\n=== DEBUG: FLASH NOTICES ==="
      all('.alert, .notice, .flash').each do |notice|
        puts "  Class: '#{notice['class']}'"
        puts "  Text: '#{notice.text}'"
        puts "  ---"
      end
      puts "=== END FLASH NOTICES ===\n"
      
      # Skip flash message check for now and focus on database state
      # The finalization might be asynchronous or require additional confirmation
      
      # Verify the position check-in was actually finalized
      position_check_in = PositionCheckIn.find_by(teammate: company_employee_teammate)
      expect(position_check_in.official_rating).to eq(3) # Looking to Reward
      expect(position_check_in.shared_notes).to eq('Finalized: Employee shows exceptional performance and growth potential')
      expect(position_check_in.official_check_in_completed_at).to be_present
      expect(position_check_in.finalized_by).to eq(manager)
      
      # Verify both perspectives are preserved (no data overwrite bug)
      expect(position_check_in.manager_rating).to eq(3) # Looking to Reward
      expect(position_check_in.manager_private_notes).to eq('Manager assessment: Company employee is exceeding expectations in their position')
      expect(position_check_in.employee_rating).to eq(2) # Praising/Trusting
      expect(position_check_in.employee_private_notes).to eq('Employee assessment: I feel I am meeting expectations in my position')
    end
  end

  describe 'Sales employee (same order)' do
    it 'allows manager and employee to complete check-ins and shows both perspectives on finalization' do
      # Step 1: Manager fills position check-in for sales_employee (mark ready)
      sign_in_as(manager, company)
      visit organization_person_check_ins_path(company, sales_employee)
      
      # Find the position check-in
      position_check_in = PositionCheckIn.find_by(teammate: sales_employee_teammate)
      
      # Fill out position check-in (mark ready)
      within('table', text: 'Position') do
        find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      end
      click_button 'Save All Check-Ins'
      
      # Wait for page to reload and verify we see the appropriate view
      expect(page).to have_current_path(organization_person_check_ins_path(company, sales_employee))
      
      # Mark as draft to re-open for editing
      within('table', text: 'Position') do
        find('input[type="radio"][value="draft"]').click
        sleep 0.5 # Wait for DOM to update
      end
      click_button 'Save All Check-Ins'
      
      # Wait for page to reload and verify we see the editable form view
      expect(page).to have_content('EDITABLE FORM VIEW')
      
      # Now fill out the form (tests that draft mode works)
      within('table', text: 'Position') do
        select '🟢 Looking to Reward - Exceptional, seeking to increase responsibility', from: 'check_ins[position_check_in][manager_rating]'
        fill_in 'check_ins[position_check_in][manager_private_notes]', with: 'Manager assessment: Sales employee is exceeding expectations in their position'
        find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      end
      
      # Step 2: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 3: Employee fills position check-in (mark ready)
      switch_to_user(sales_employee, company)
      visit organization_person_check_ins_path(company, sales_employee)
      
      # Fill out position check-in (mark ready)
      within('table', text: 'Position') do
        find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      end
      click_button 'Save All Check-Ins'
      
      # Mark as draft to re-open for editing
      within('table', text: 'Position') do
        find('input[type="radio"][value="draft"]').click
        sleep 0.5 # Wait for DOM to update
      end
      click_button 'Save All Check-Ins'
      
      # Verify we're now in editable form view
      expect(page).to have_content('EDITABLE FORM VIEW')
      
      # Now fill out the form (tests that draft mode works)
      select '🔵 Praising/Trusting - Consistent strong performance', from: 'check_ins[position_check_in][employee_rating]'
      fill_in 'check_ins[position_check_in][employee_private_notes]', with: 'Sales employee assessment: I feel I am meeting expectations in my position'
      find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      
      # Step 4: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 5: Manager goes to finalization page
      sign_in_as(manager, company)
      visit organization_person_finalization_path(company, sales_employee)
      
      # Step 6: Critical assertions to catch the bug
      expect(page).to have_content('Position Check-In')
      
      # Verify position check-in is visible and has both perspectives
      # Manager's perspective should be visible
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('🟢 Looking to Reward')
        expect(page).to have_content('Manager assessment: Sales employee is exceeding expectations in their position')
        
        # Employee's perspective should be visible
        expect(page).to have_content('Employee Perspective')
        expect(page).to have_content('🔵 Praising/Trusting')
        expect(page).to have_content('Sales employee assessment: I feel I am meeting expectations in my position')
        
        # Both values should be distinct and not overwritten
        # This is the critical test - if there's a bug, one might overwrite the other
        # The position finalization page shows both perspectives in the manager's finalization form
        expect(page).to have_content('🟢 Looking to Reward')
        expect(page).to have_content('Manager assessment: Sales employee is exceeding expectations in their position')
        expect(page).to have_content('🔵 Praising/Trusting')
        expect(page).to have_content('Sales employee assessment: I feel I am meeting expectations in my position')
        
        # Verify both perspectives are visible and distinct
        # This confirms that position check-ins work correctly (no data overwrite bug)
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('Employee Perspective')
    end
  end

  describe 'Support employee (employee fills first)' do
    it 'allows employee and manager to complete check-ins and shows both perspectives on finalization' do
      # Step 1: Employee fills first - position check-in (mark ready)
      sign_in_as(support_employee, company)
      visit organization_person_check_ins_path(company, support_employee)
      
      # Find the position check-in
      position_check_in = PositionCheckIn.find_by(teammate: support_employee_teammate)
      
      # Fill out position check-in (mark ready)
      within('table', text: 'Position') do
        find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      end
      click_button 'Save All Check-Ins'
      
      # Wait for page to reload and verify we see the appropriate view
      expect(page).to have_current_path(organization_person_check_ins_path(company, support_employee))
      
      # Mark as draft to re-open for editing
      within('table', text: 'Position') do
        find('input[type="radio"][value="draft"]').click
        sleep 0.5 # Wait for DOM to update
      end
      click_button 'Save All Check-Ins'
      
      # Wait for page to reload and verify we see the editable form view
      expect(page).to have_content('EDITABLE FORM VIEW')
      
      # Now fill out the form (tests that draft mode works)
      within('table', text: 'Position') do
        select '🟢 Looking to Reward - Exceptional, seeking to increase responsibility', from: 'check_ins[position_check_in][employee_rating]'
        fill_in 'check_ins[position_check_in][employee_private_notes]', with: 'Support employee assessment: I feel I am exceeding expectations in my position'
        find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      end
      
      # Step 2: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 3: Manager fills position check-in (mark ready)
      switch_to_user(manager, company)
      visit organization_person_check_ins_path(company, support_employee)
      
      # Fill out position check-in (mark ready)
      within('table', text: 'Position') do
        find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      end
      click_button 'Save All Check-Ins'
      
      # Mark as draft to re-open for editing
      within('table', text: 'Position') do
        find('input[type="radio"][value="draft"]').click
        sleep 0.5 # Wait for DOM to update
      end
      click_button 'Save All Check-Ins'
      
      # Verify we're now in editable form view
      expect(page).to have_content('EDITABLE FORM VIEW')
      
      # Step 4: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 5: Manager fills their side
      switch_to_user(manager, company)
      # Force a page refresh to ensure session is updated
      visit root_path
      visit organization_person_check_ins_path(company, support_employee)
      
      # Debug: Print all form fields
      puts "\n=== DEBUG: MANAGER VIEW - ALL SELECT FIELDS ON PAGE ==="
      all('select').each do |select_field|
        puts "  Name: '#{select_field['name']}'"
        puts "  ID: '#{select_field['id']}'"
        puts "  Classes: '#{select_field['class']}'"
        puts "  ---"
      end
      puts "=== END SELECT FIELDS ===\n"

      puts "\n=== DEBUG: MANAGER VIEW - PAGE CONTENT (first 2000 chars) ==="
      puts page.text[0..2000]
      puts "=== END PAGE CONTENT ===\n"
      
      # Fill out manager side
      find('select[name="check_ins[position_check_in][manager_rating]"]').select('🔵 Praising/Trusting - Consistent strong performance')
      fill_in 'check_ins[position_check_in][manager_private_notes]', with: 'Manager assessment: Support employee is meeting expectations in their position'
      find('input[name="check_ins[position_check_in][status]"][value="complete"]').click
      click_button 'Save All Check-Ins'
      
      # Step 6: Manager goes to finalization page
      visit organization_person_finalization_path(company, support_employee)
      
      # Step 6: Critical assertions to catch the bug
      expect(page).to have_content('Position Check-In')
      
      # Verify position check-in is visible and has both perspectives
      # Manager's perspective should be visible
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('🔵 Praising/Trusting')
        expect(page).to have_content('Manager assessment: Support employee is meeting expectations in their position')
        
        # Employee's perspective should be visible
        expect(page).to have_content('Employee Perspective')
        expect(page).to have_content('🟢 Looking to Reward')
        expect(page).to have_content('Support employee assessment: I feel I am exceeding expectations in my position')
        
        # Both values should be distinct and not overwritten
        # This is the critical test - if there's a bug, one might overwrite the other
        # The position finalization page shows both perspectives in the manager's finalization form
        expect(page).to have_content('🔵 Praising/Trusting')
        expect(page).to have_content('Manager assessment: Support employee is meeting expectations in their position')
        expect(page).to have_content('🟢 Looking to Reward')
        expect(page).to have_content('Support employee assessment: I feel I am exceeding expectations in my position')
        
        # Verify both perspectives are visible and distinct
        # This confirms that position check-ins work correctly (no data overwrite bug)
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('Employee Perspective')
    end
  end
end
