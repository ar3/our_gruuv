require 'rails_helper'

RSpec.describe 'Check-In Finalization Flow', type: :system do
  include_context 'check_in_test_data'

  describe 'Company-level assignments (manager fills first)' do
    it 'allows manager and employee to complete check-ins and shows both perspectives on finalization' do
      # Step 9: Manager associates company assignments with company-level employee
      sign_in_as(manager, company)
      
      # Create assignment tenures for company assignments
      create(:assignment_tenure, teammate: company_employee_teammate, assignment: company_assignment_1, anticipated_energy_percentage: 80)
      create(:assignment_tenure, teammate: company_employee_teammate, assignment: company_assignment_2, anticipated_energy_percentage: 60)
      
      # Step 10: Manager fills company-assignment-1 (mark ready) and company-assignment-2 (draft)
      visit organization_person_check_ins_path(company, company_employee)
      
      # Find the assignment check-ins
      assignment_check_in_1 = AssignmentCheckIn.find_by(teammate: company_employee_teammate, assignment: company_assignment_1)
      assignment_check_in_2 = AssignmentCheckIn.find_by(teammate: company_employee_teammate, assignment: company_assignment_2)
      
      # Fill out company-assignment-1 (mark ready)
      first('select[name*="assignment_check_ins"][name*="manager_rating"]').select('Exceeding')
      first('textarea[name*="assignment_check_ins"][name*="manager_private_notes"]').set('Manager thinks employee is exceeding expectations on company strategy')
      first('input[name*="assignment_check_ins"][name*="status"][value="complete"]').click
      
      # Fill out company-assignment-2 (save as draft)
      all('select[name*="assignment_check_ins"][name*="manager_rating"]').last.select('Meeting')
      all('textarea[name*="assignment_check_ins"][name*="manager_private_notes"]').last.set('Manager thinks employee is meeting expectations on company operations')
      all('input[name*="assignment_check_ins"][name*="status"][value="draft"]').last.click
      
      # Step 11: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 12: Employee fills company-assignment-1 (mark ready) and company-assignment-2 (draft)
      switch_to_user(company_employee, company)
      visit organization_person_check_ins_path(company, company_employee)
      
      # Fill out company-assignment-1 (mark ready)
      first('select[name*="assignment_check_ins"][name*="employee_rating"]').select('Meeting')
      first('textarea[name*="assignment_check_ins"][name*="employee_private_notes"]').set('Employee thinks they are meeting expectations on company strategy')
      first('input[name*="assignment_check_ins"][name*="actual_energy_percentage"]').set('75')
      first('select[name*="assignment_check_ins"][name*="employee_personal_alignment"]').select('Like')
      first('input[name*="assignment_check_ins"][name*="status"][value="complete"]').click
      
      # Fill out company-assignment-2 (save as draft)
      all('select[name*="assignment_check_ins"][name*="employee_rating"]').last.select('Working to Meet')
      all('textarea[name*="assignment_check_ins"][name*="employee_private_notes"]').last.set('Employee thinks they are working to meet expectations on company operations')
      all('input[name*="assignment_check_ins"][name*="actual_energy_percentage"]').last.set('50')
      all('select[name*="assignment_check_ins"][name*="employee_personal_alignment"]').last.select('Neutral')
      all('input[name*="assignment_check_ins"][name*="status"][value="draft"]').last.click
      
      # Step 13: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 14: Manager goes to finalization page
      switch_to_user(manager, company)
      visit organization_person_finalization_path(company, company_employee)
      
      # Step 15: Critical assertions to catch the bug
      expect(page).to have_content('Company Strategy')
      
      # Verify company-assignment-1 is visible and has both perspectives
      within('.assignment-finalization', text: 'Company Strategy') do
        # Manager's perspective should be visible
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('Exceeding')
        expect(page).to have_content('Manager thinks employee is exceeding expectations on company strategy')
        
        # Employee's perspective should be visible
        expect(page).to have_content('Employee Perspective')
        expect(page).to have_content('Meeting')
        expect(page).to have_content('Employee thinks they are meeting expectations on company strategy')
        expect(page).to have_content('75%')
        expect(page).to have_content('Like')
        
        # Both values should be distinct and not overwritten
        # This is the critical test - if there's a bug, one might overwrite the other
        # In the manager view, we need to check that both perspectives are visible in the same section
        expect(page).to have_content('Exceeding')
        expect(page).to have_content('Manager thinks employee is exceeding expectations on company strategy')
        expect(page).to have_content('Meeting')
        expect(page).to have_content('Employee thinks they are meeting expectations on company strategy')
        
        # Verify the manager and employee data are distinct and not mixed up
        manager_perspective_section = page.find('.manager-perspective')
        employee_perspective_section = page.find('.employee-perspective')
        
        expect(manager_perspective_section).to have_content('Exceeding')
        expect(manager_perspective_section).to have_content('Manager thinks employee is exceeding expectations on company strategy')
        expect(manager_perspective_section).not_to have_content('Meeting')
        expect(manager_perspective_section).not_to have_content('Employee thinks')
        
        expect(employee_perspective_section).to have_content('Meeting')
        expect(employee_perspective_section).to have_content('Employee thinks they are meeting expectations on company strategy')
        expect(employee_perspective_section).not_to have_content('Exceeding')
        expect(employee_perspective_section).not_to have_content('Manager thinks')
      end
    end
  end

  describe 'Sales department-level assignments (same order)' do
    it 'allows manager and employee to complete check-ins and shows both perspectives on finalization' do
      # Step 9: Manager associates sales assignments with sales-level employee
      sign_in_as(manager, company)
      
      # Create assignment tenures for sales assignments
      create(:assignment_tenure, teammate: sales_employee_teammate, assignment: sales_assignment_1, anticipated_energy_percentage: 70)
      create(:assignment_tenure, teammate: sales_employee_teammate, assignment: sales_assignment_2, anticipated_energy_percentage: 50)
      
      # Step 10: Manager fills sales-assignment-1 (mark ready) and sales-assignment-2 (draft)
      visit organization_person_check_ins_path(company, sales_employee)
      
      # Find the assignment check-ins
      assignment_check_in_1 = AssignmentCheckIn.find_by(teammate: sales_employee_teammate, assignment: sales_assignment_1)
      assignment_check_in_2 = AssignmentCheckIn.find_by(teammate: sales_employee_teammate, assignment: sales_assignment_2)
      
      # Fill out sales-assignment-1 (mark ready)
      first('select[name*="assignment_check_ins"][name*="manager_rating"]').select('Exceeding')
      first('textarea[name*="assignment_check_ins"][name*="manager_private_notes"]').set('Manager thinks sales employee is exceeding expectations on sales growth')
      first('input[name*="assignment_check_ins"][name*="status"][value="complete"]').click
      
      # Fill out sales-assignment-2 (save as draft)
      all('select[name*="assignment_check_ins"][name*="manager_rating"]').last.select('Meeting')
      all('textarea[name*="assignment_check_ins"][name*="manager_private_notes"]').last.set('Manager thinks sales employee is meeting expectations on customer acquisition')
      all('input[name*="assignment_check_ins"][name*="status"][value="draft"]').last.click
      
      # Step 11: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 12: Employee fills sales-assignment-1 (mark ready) and sales-assignment-2 (draft)
      switch_to_user(sales_employee, company)
      visit organization_person_check_ins_path(company, sales_employee)
      
      # Fill out sales-assignment-1 (mark ready)
      first('select[name*="assignment_check_ins"][name*="employee_rating"]').select('Meeting')
      first('textarea[name*="assignment_check_ins"][name*="employee_private_notes"]').set('Sales employee thinks they are meeting expectations on sales growth')
      first('input[name*="assignment_check_ins"][name*="actual_energy_percentage"]').set('65')
      first('select[name*="assignment_check_ins"][name*="employee_personal_alignment"]').select('Like')
      first('input[name*="assignment_check_ins"][name*="status"][value="complete"]').click
      
      # Fill out sales-assignment-2 (save as draft)
      all('select[name*="assignment_check_ins"][name*="employee_rating"]').last.select('Working to Meet')
      all('textarea[name*="assignment_check_ins"][name*="employee_private_notes"]').last.set('Sales employee thinks they are working to meet expectations on customer acquisition')
      all('input[name*="assignment_check_ins"][name*="actual_energy_percentage"]').last.set('45')
      all('select[name*="assignment_check_ins"][name*="employee_personal_alignment"]').last.select('Neutral')
      all('input[name*="assignment_check_ins"][name*="status"][value="draft"]').last.click
      
      # Step 13: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 14: Manager goes to finalization page
      switch_to_user(manager, company)
      visit organization_person_finalization_path(company, sales_employee)
      
      # Step 15: Critical assertions to catch the bug
      expect(page).to have_content('Sales Growth')
      
      # Verify sales-assignment-1 is visible and has both perspectives
      within('.assignment-finalization', text: 'Sales Growth') do
        # Manager's perspective should be visible
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('Exceeding')
        expect(page).to have_content('Manager thinks sales employee is exceeding expectations on sales growth')
        
        # Employee's perspective should be visible
        expect(page).to have_content('Employee Perspective')
        expect(page).to have_content('Meeting')
        expect(page).to have_content('Sales employee thinks they are meeting expectations on sales growth')
        expect(page).to have_content('65%')
        expect(page).to have_content('Like')
        
        # Both values should be distinct and not overwritten
        # In the manager view, we need to check that both perspectives are visible in the same section
        expect(page).to have_content('Exceeding')
        expect(page).to have_content('Manager thinks sales employee is exceeding expectations on sales growth')
        expect(page).to have_content('Meeting')
        expect(page).to have_content('Sales employee thinks they are meeting expectations on sales growth')
        
        # Verify the manager and employee data are distinct and not mixed up
        manager_perspective_section = page.find('.manager-perspective')
        employee_perspective_section = page.find('.employee-perspective')
        
        expect(manager_perspective_section).to have_content('Exceeding')
        expect(manager_perspective_section).to have_content('Manager thinks sales employee is exceeding expectations on sales growth')
        expect(manager_perspective_section).not_to have_content('Meeting')
        expect(manager_perspective_section).not_to have_content('Sales employee thinks')
        
        expect(employee_perspective_section).to have_content('Meeting')
        expect(employee_perspective_section).to have_content('Sales employee thinks they are meeting expectations on sales growth')
        expect(employee_perspective_section).not_to have_content('Exceeding')
        expect(employee_perspective_section).not_to have_content('Manager thinks')
      end
    end
  end

  describe 'Support department-level assignments (employee fills first)' do
    it 'allows employee and manager to complete check-ins and shows both perspectives on finalization' do
      # Step 9: Manager associates support assignments with support-level employee
      sign_in_as(manager, company)
      
      # Create assignment tenures for support assignments
      create(:assignment_tenure, teammate: support_employee_teammate, assignment: support_assignment_1, anticipated_energy_percentage: 90)
      create(:assignment_tenure, teammate: support_employee_teammate, assignment: support_assignment_2, anticipated_energy_percentage: 40)
      
      # Step 10: Employee fills first - support-assignment-1 (mark ready) and support-assignment-2 (draft)
      switch_to_user(support_employee, company)
      visit organization_person_check_ins_path(company, support_employee)
      
      # Find the assignment check-ins
      assignment_check_in_1 = AssignmentCheckIn.find_by(teammate: support_employee_teammate, assignment: support_assignment_1)
      assignment_check_in_2 = AssignmentCheckIn.find_by(teammate: support_employee_teammate, assignment: support_assignment_2)
      
      # Fill out support-assignment-1 (mark ready)
      first('select[name*="assignment_check_ins"][name*="employee_rating"]').select('Exceeding')
      first('textarea[name*="assignment_check_ins"][name*="employee_private_notes"]').set('Support employee thinks they are exceeding expectations on customer support')
      first('input[name*="assignment_check_ins"][name*="actual_energy_percentage"]').set('85')
      first('select[name*="assignment_check_ins"][name*="employee_personal_alignment"]').select('Love')
      first('input[name*="assignment_check_ins"][name*="status"][value="complete"]').click
      
      # Fill out support-assignment-2 (save as draft)
      all('select[name*="assignment_check_ins"][name*="employee_rating"]').last.select('Meeting')
      all('textarea[name*="assignment_check_ins"][name*="employee_private_notes"]').last.set('Support employee thinks they are meeting expectations on support documentation')
      all('input[name*="assignment_check_ins"][name*="actual_energy_percentage"]').last.set('35')
      all('select[name*="assignment_check_ins"][name*="employee_personal_alignment"]').last.select('Neutral')
      all('input[name*="assignment_check_ins"][name*="status"][value="draft"]').last.click
      
      # Step 11: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 12: Manager fills support-assignment-1 (mark ready) and support-assignment-2 (draft)
      switch_to_user(manager, company)
      visit organization_person_check_ins_path(company, support_employee)
      
      # Fill out support-assignment-1 (mark ready)
      first('select[name*="assignment_check_ins"][name*="manager_rating"]').select('Meeting')
      first('textarea[name*="assignment_check_ins"][name*="manager_private_notes"]').set('Manager thinks support employee is meeting expectations on customer support')
      first('input[name*="assignment_check_ins"][name*="status"][value="complete"]').click
      
      # Fill out support-assignment-2 (save as draft)
      all('select[name*="assignment_check_ins"][name*="manager_rating"]').last.select('Working to Meet')
      all('textarea[name*="assignment_check_ins"][name*="manager_private_notes"]').last.set('Manager thinks support employee is working to meet expectations on support documentation')
      all('input[name*="assignment_check_ins"][name*="status"][value="draft"]').last.click
      
      # Step 13: Submit
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Step 14: Manager goes to finalization page
      visit organization_person_finalization_path(company, support_employee)
      
      # Step 15: Critical assertions to catch the bug
      expect(page).to have_content('Customer Support')
      
      # Verify support-assignment-1 is visible and has both perspectives
      within('.assignment-finalization', text: 'Customer Support') do
        # Manager's perspective should be visible
        expect(page).to have_content('Manager Perspective')
        expect(page).to have_content('Meeting')
        expect(page).to have_content('Manager thinks support employee is meeting expectations on customer support')
        
        # Employee's perspective should be visible
        expect(page).to have_content('Employee Perspective')
        expect(page).to have_content('Exceeding')
        expect(page).to have_content('Support employee thinks they are exceeding expectations on customer support')
        expect(page).to have_content('85%')
        expect(page).to have_content('Love')
        
        # Both values should be distinct and not overwritten
        # This tests if order matters - employee filled first, then manager
        # In the manager view, we need to check that both perspectives are visible in the same section
        expect(page).to have_content('Meeting')
        expect(page).to have_content('Manager thinks support employee is meeting expectations on customer support')
        expect(page).to have_content('Exceeding')
        expect(page).to have_content('Support employee thinks they are exceeding expectations on customer support')
        
        # Verify the manager and employee data are distinct and not mixed up
        manager_perspective_section = page.find('.manager-perspective')
        employee_perspective_section = page.find('.employee-perspective')
        
        expect(manager_perspective_section).to have_content('Meeting')
        expect(manager_perspective_section).to have_content('Manager thinks support employee is meeting expectations on customer support')
        expect(manager_perspective_section).not_to have_content('Exceeding')
        expect(manager_perspective_section).not_to have_content('Support employee thinks')
        
        expect(employee_perspective_section).to have_content('Exceeding')
        expect(employee_perspective_section).to have_content('Support employee thinks they are exceeding expectations on customer support')
        expect(employee_perspective_section).not_to have_content('Meeting')
        expect(employee_perspective_section).not_to have_content('Manager thinks')
      end
    end
  end
end
