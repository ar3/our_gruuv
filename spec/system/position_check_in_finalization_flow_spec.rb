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
        select '🟢 Looking to Reward - Exceptional, seeking to increase responsibility', from: '[position_check_in][manager_rating]'
        fill_in '[position_check_in][manager_private_notes]', with: 'Manager assessment: Company employee is exceeding expectations in their position'
        find('input[type="radio"][value="complete"]').click
      end
      
      # Step 2: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 3: Employee fills position check-in (mark ready)
      switch_to_user(company_employee, company)
      visit organization_person_check_ins_path(company, company_employee)
      
      # Fill out position check-in (mark ready)
      within('table', text: 'Position') do
        select '🔵 Praising/Trusting - Consistent strong performance', from: '[position_check_in][employee_rating]'
        fill_in '[position_check_in][employee_private_notes]', with: 'Employee assessment: I feel I am meeting expectations in my position'
        find('input[type="radio"][value="complete"]').click
      end
      
      # Step 4: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 5: Manager goes to finalization page
      switch_to_user(manager, company)
      visit organization_person_finalization_path(company, company_employee)
      
      # Step 6: Critical assertions to catch the bug
      expect(page).to have_content('Position Check-In')
      
      # Verify position check-in is visible and has both perspectives
      # Manager's perspective should be visible
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('🟢 Looking to Reward')
        expect(page).to have_content('Manager assessment: Company employee is exceeding expectations in their position')
        
        # Employee's perspective should be visible
        expect(page).to have_content('Employee Perspective')
        expect(page).to have_content('🔵 Praising/Trusting')
        expect(page).to have_content('Employee assessment: I feel I am meeting expectations in my position')
        
        # Both values should be distinct and not overwritten
        # This is the critical test - if there's a bug, one might overwrite the other
        # The position finalization page shows both perspectives in the manager's finalization form
        expect(page).to have_content('🟢 Looking to Reward')
        expect(page).to have_content('Manager assessment: Company employee is exceeding expectations in their position')
        expect(page).to have_content('🔵 Praising/Trusting')
        expect(page).to have_content('Employee assessment: I feel I am meeting expectations in my position')
        
        # Verify both perspectives are visible and distinct
        # This confirms that position check-ins work correctly (no data overwrite bug)
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('Employee Perspective')
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
        select '🟢 Looking to Reward - Exceptional, seeking to increase responsibility', from: '[position_check_in][manager_rating]'
        fill_in '[position_check_in][manager_private_notes]', with: 'Manager assessment: Sales employee is exceeding expectations in their position'
        find('input[type="radio"][value="complete"]').click
      end
      
      # Step 2: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 3: Employee fills position check-in (mark ready)
      switch_to_user(sales_employee, company)
      visit organization_person_check_ins_path(company, sales_employee)
      
      # Fill out position check-in (mark ready)
      within('table', text: 'Position') do
        select '🔵 Praising/Trusting - Consistent strong performance', from: '[position_check_in][employee_rating]'
        fill_in '[position_check_in][employee_private_notes]', with: 'Sales employee assessment: I feel I am meeting expectations in my position'
        find('input[type="radio"][value="complete"]').click
      end
      
      # Step 4: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 5: Manager goes to finalization page
      switch_to_user(manager, company)
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
        select '🟢 Looking to Reward - Exceptional, seeking to increase responsibility', from: '[position_check_in][employee_rating]'
        fill_in '[position_check_in][employee_private_notes]', with: 'Support employee assessment: I feel I am exceeding expectations in my position'
        find('input[type="radio"][value="complete"]').click
      end
      
      # Step 2: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 3: Manager fills position check-in (mark ready)
      switch_to_user(manager, company)
      visit organization_person_check_ins_path(company, support_employee)
      
      # Fill out position check-in (mark ready)
      within('table', text: 'Position') do
        select '🔵 Praising/Trusting - Consistent strong performance', from: '[position_check_in][manager_rating]'
        fill_in '[position_check_in][manager_private_notes]', with: 'Manager assessment: Support employee is meeting expectations in their position'
        find('input[type="radio"][value="complete"]').click
      end
      
      # Step 4: Submit
      click_button 'Save All Check-Ins'
      # expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully', visible: :all)
      
      # Step 5: Manager goes to finalization page
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
