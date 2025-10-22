require 'rails_helper'

RSpec.describe 'Aspiration Check-In Finalization Flow', type: :system do
  include_context 'check_in_test_data'

  describe 'Company-level aspirations (manager fills first)' do
    it 'allows manager and employee to complete check-ins and shows both perspectives on finalization' do
      # Step 1: Manager fills company-aspiration-1 (mark ready) and company-aspiration-2 (draft)
      sign_in_as(manager, company)
      visit organization_person_check_ins_path(company, company_employee)
      
      # Find the aspiration check-ins
      aspiration_check_in_1 = AspirationCheckIn.find_by(teammate: company_employee_teammate, aspiration: company_aspiration_1)
      aspiration_check_in_2 = AspirationCheckIn.find_by(teammate: company_employee_teammate, aspiration: company_aspiration_2)
      
      # Fill out company-aspiration-1 (mark ready)
      first('select[name*="aspiration_check_ins"][name*="manager_rating"]').select('Exceeding')
      first('textarea[name*="aspiration_check_ins"][name*="manager_private_notes"]').set('Manager thinks employee is exceeding expectations on company growth')
      first('input[name*="aspiration_check_ins"][name*="status"][value="complete"]').click
      
      # Fill out company-aspiration-2 (save as draft)
      all('select[name*="aspiration_check_ins"][name*="manager_rating"]').last.select('Meeting')
      all('textarea[name*="aspiration_check_ins"][name*="manager_private_notes"]').last.set('Manager thinks employee is meeting expectations on innovation')
      all('input[name*="aspiration_check_ins"][name*="status"][value="draft"]').last.click
      
      # Step 2: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 3: Employee fills company-aspiration-1 (mark ready) and company-aspiration-2 (draft)
      switch_to_user(company_employee, company)
      visit organization_person_check_ins_path(company, company_employee)
      
      # Fill out company-aspiration-1 (mark ready)
      first('select[name*="aspiration_check_ins"][name*="employee_rating"]').select('Meeting')
      first('textarea[name*="aspiration_check_ins"][name*="employee_private_notes"]').set('Employee thinks they are meeting expectations on company growth')
      first('input[name*="aspiration_check_ins"][name*="status"][value="complete"]').click
      
      # Fill out company-aspiration-2 (save as draft)
      all('select[name*="aspiration_check_ins"][name*="employee_rating"]').last.select('Working to Meet')
      all('textarea[name*="aspiration_check_ins"][name*="employee_private_notes"]').last.set('Employee thinks they are working to meet expectations on innovation')
      all('input[name*="aspiration_check_ins"][name*="status"][value="draft"]').last.click
      
      # Step 4: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 5: Manager goes to finalization page
      switch_to_user(manager, company)
      visit organization_person_finalization_path(company, company_employee)
      
      # Step 6: Critical assertions to catch the bug
      expect(page).to have_content('Company Growth')
      
      # Verify company-aspiration-1 is visible and has both perspectives
      within('.aspiration-finalization', text: 'Company Growth') do
        # Manager's perspective should be visible
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('Exceeding')
        expect(page).to have_content('Manager thinks employee is exceeding expectations on company growth')
        
        # Employee's perspective should be visible
        expect(page).to have_content('Employee Perspective')
        expect(page).to have_content('Meeting')
        expect(page).to have_content('Employee thinks they are meeting expectations on company growth')
        
        # Both values should be distinct and not overwritten
        # This is the critical test - if there's a bug, one might overwrite the other
        manager_section = page.find('.card.border-info')
        employee_section = page.find('.card.border-primary')
        
        expect(manager_section).to have_content('Exceeding')
        expect(manager_section).to have_content('Manager thinks employee is exceeding expectations on company growth')
        expect(manager_section).not_to have_content('Meeting')
        expect(manager_section).not_to have_content('Employee thinks')
        
        expect(employee_section).to have_content('Meeting')
        expect(employee_section).to have_content('Employee thinks they are meeting expectations on company growth')
        expect(employee_section).not_to have_content('Exceeding')
        expect(employee_section).not_to have_content('Manager thinks')
      end
    end
  end

  describe 'Sales department aspirations (same order)' do
    it 'allows manager and employee to complete check-ins and shows both perspectives on finalization' do
      # Step 1: Manager fills sales-aspiration (mark ready)
      sign_in_as(manager, company)
      visit organization_person_check_ins_path(company, sales_employee)
      
      # Find the aspiration check-in
      aspiration_check_in = AspirationCheckIn.find_by(teammate: sales_employee_teammate, aspiration: sales_aspiration)
      
      # Fill out sales-aspiration (mark ready)
      first('select[name*="aspiration_check_ins"][name*="manager_rating"]').select('Exceeding')
      first('textarea[name*="aspiration_check_ins"][name*="manager_private_notes"]').set('Manager thinks sales employee is exceeding expectations on sales excellence')
      first('input[name*="aspiration_check_ins"][name*="status"][value="complete"]').click
      
      # Step 2: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 3: Employee fills sales-aspiration (mark ready)
      switch_to_user(sales_employee, company)
      visit organization_person_check_ins_path(company, sales_employee)
      
      # Fill out sales-aspiration (mark ready)
      first('select[name*="aspiration_check_ins"][name*="employee_rating"]').select('Meeting')
      first('textarea[name*="aspiration_check_ins"][name*="employee_private_notes"]').set('Sales employee thinks they are meeting expectations on sales excellence')
      first('input[name*="aspiration_check_ins"][name*="status"][value="complete"]').click
      
      # Step 4: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 5: Manager goes to finalization page
      switch_to_user(manager, company)
      visit organization_person_finalization_path(company, sales_employee)
      
      # Step 6: Critical assertions to catch the bug
      # Verify sales-aspiration is visible and has both perspectives
      expect(page).to have_content('Manager Perspective')
      expect(page).to have_content('Exceeding')
      expect(page).to have_content('Manager thinks sales employee is exceeding expectations on sales excellence')
      
      # Employee's perspective should be visible
      expect(page).to have_content('Employee Perspective')
      expect(page).to have_content('Meeting')
      expect(page).to have_content('Sales employee thinks they are meeting expectations on sales excellence')
    end
  end

  describe 'Support department aspirations (employee fills first)' do
    it 'allows employee and manager to complete check-ins and shows both perspectives on finalization' do
      # Step 1: Employee fills first - support-aspiration (mark ready)
      sign_in_as(support_employee, company)
      visit organization_person_check_ins_path(company, support_employee)
      
      # Find the aspiration check-in
      aspiration_check_in = AspirationCheckIn.find_by(teammate: support_employee_teammate, aspiration: support_aspiration)
      
      # Fill out support-aspiration (mark ready)
      first('select[name*="aspiration_check_ins"][name*="employee_rating"]').select('Exceeding')
      first('textarea[name*="aspiration_check_ins"][name*="employee_private_notes"]').set('Support employee thinks they are exceeding expectations on customer support')
      first('input[name*="aspiration_check_ins"][name*="status"][value="complete"]').click
      
      # Step 2: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 3: Manager fills support-aspiration (mark ready)
      switch_to_user(manager, company)
      visit organization_person_check_ins_path(company, support_employee)
      
      # Fill out support-aspiration (mark ready)
      first('select[name*="aspiration_check_ins"][name*="manager_rating"]').select('Meeting')
      first('textarea[name*="aspiration_check_ins"][name*="manager_private_notes"]').set('Manager thinks support employee is meeting expectations on customer support')
      first('input[name*="aspiration_check_ins"][name*="status"][value="complete"]').click
      
      # Step 4: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 5: Manager goes to finalization page
      visit organization_person_finalization_path(company, support_employee)
      
      # Step 6: Critical assertions to catch the bug
      # Verify support-aspiration is visible and has both perspectives
      expect(page).to have_content('Manager Perspective')
      expect(page).to have_content('Meeting')
      expect(page).to have_content('Manager thinks support employee is meeting expectations on customer support')
      
      # Employee's perspective should be visible
      expect(page).to have_content('Employee Perspective')
      expect(page).to have_content('Exceeding')
      expect(page).to have_content('Support employee thinks they are exceeding expectations on customer support')
    end
  end
end
