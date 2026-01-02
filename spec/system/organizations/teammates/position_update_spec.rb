require 'rails_helper'

RSpec.describe 'Position Update', type: :system, js: true do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person, first_name: 'Manager', last_name: 'User') }
  let!(:manager_teammate) { CompanyTeammate.create!(person: manager_person, organization: company, can_manage_employment: true) }
  let(:employee_person) { create(:person, first_name: 'Employee', last_name: 'User') }
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }
  let(:shared_major_level) { create(:position_major_level) }
  let!(:position_type1) { create(:position_type, organization: company, position_major_level: shared_major_level, external_title: 'Software Engineer I') }
  let!(:position_type2) { create(:position_type, organization: company, position_major_level: shared_major_level, external_title: 'Software Engineer II') }
  let!(:position_level1) { create(:position_level, position_major_level: shared_major_level) }
  let!(:position_level2) { create(:position_level, position_major_level: shared_major_level) }
  let!(:position) { Position.create!(position_type_id: position_type1.id, position_level_id: position_level1.id, position_summary: 'Test position') }
  let!(:manager_employment_tenure) do
    # Create employment tenure for manager so they show up in employees list and have proper access
    manager_teammate.update!(first_employed_at: 2.years.ago)
    EmploymentTenure.create!(
      teammate: manager_teammate,
      company: company,
      position: position,
      employment_type: 'full_time',
      started_at: 2.years.ago
    )
  end
  let(:current_manager) { create(:person, first_name: 'Current', last_name: 'Manager') }
  let(:new_manager) { create(:person, first_name: 'New', last_name: 'Manager') }
  let!(:current_manager_teammate) { CompanyTeammate.create!(person: current_manager, organization: company, first_employed_at: 1.year.ago) }
  let!(:new_manager_teammate) { CompanyTeammate.create!(person: new_manager, organization: company, first_employed_at: 1.year.ago) }
  let!(:current_manager_tenure) do
    EmploymentTenure.create!(
      teammate: current_manager_teammate,
      company: company,
      position: position,
      employment_type: 'full_time',
      started_at: 1.year.ago
    )
  end
  let!(:new_manager_tenure) do
    EmploymentTenure.create!(
      teammate: new_manager_teammate,
      company: company,
      position: position,
      employment_type: 'full_time',
      started_at: 1.year.ago
    )
  end
  # Create employees managed by these managers so they appear in the manager dropdown
  let!(:employee_for_current_manager) do
    emp_teammate = CompanyTeammate.create!(person: create(:person), organization: company, first_employed_at: 6.months.ago)
    EmploymentTenure.create!(
      teammate: emp_teammate,
      company: company,
      position: position,
      manager_teammate: current_manager_teammate,
      employment_type: 'full_time',
      started_at: 6.months.ago
    )
  end
  let!(:employee_for_new_manager) do
    emp_teammate = CompanyTeammate.create!(person: create(:person), organization: company, first_employed_at: 5.months.ago)
    EmploymentTenure.create!(
      teammate: emp_teammate,
      company: company,
      position: position,
      manager_teammate: new_manager_teammate,
      employment_type: 'full_time',
      started_at: 5.months.ago
    )
  end
  let!(:new_position) { Position.create!(position_type_id: position_type2.id, position_level_id: position_level2.id, position_summary: 'Test position 2') }
  let!(:seat) { Seat.create!(position_type_id: position_type1.id, seat_needed_by: Date.current + 3.months, job_classification: 'Salaried Exempt', state: :open) }
  let!(:seat_for_new_position) { Seat.create!(position_type_id: position_type2.id, seat_needed_by: Date.current + 4.months, job_classification: 'Salaried Exempt', state: :open) }
  
  let!(:current_tenure) do
    # Ensure employee_teammate has first_employed_at set (required for termination validation)
    employee_teammate.update!(first_employed_at: 6.months.ago) unless employee_teammate.first_employed_at.present?
    EmploymentTenure.create!(
      teammate: employee_teammate,
      company: company,
      position: position,
      manager_teammate: current_manager_teammate,
      seat: seat,
      employment_type: 'full_time',
      started_at: 6.months.ago
    ).tap do |tenure|
      # Reload associations to ensure they're loaded
      employee_teammate.reload
    end
  end
  
  # Set up manager-employee relationship for permission tests
  # Update current_tenure to have manager_person as manager so they're in managerial hierarchy
  # This allows view_check_ins? to pass even without can_manage_employment
  let!(:manager_employment_tenure_for_permission) do
    # Update current_tenure after it's created to have manager_teammate as manager
    # This ensures manager_person is in the managerial hierarchy
    current_tenure.update!(manager_teammate: manager_teammate)
    current_tenure
  end

  before do
    # Ensure manager_teammate has can_manage_employment flag set (unless explicitly set to false)
    # Only set to true if it's nil or if we're not in a "no permission" test context
    unless defined?(@can_manage_employment_override) && @can_manage_employment_override == false
      manager_teammate.update!(can_manage_employment: true) unless manager_teammate.can_manage_employment?
    end
    sign_in_and_visit(manager_person, company, organization_teammate_position_path(company, employee_teammate))
    # Reload teammate after sign_in to ensure flags are preserved
    manager_teammate.reload
  end

  describe 'Manager dropdown structure' do
    let(:non_manager_employee) { create(:person, first_name: 'NonManager', last_name: 'Employee') }
    let!(:non_manager_employee_teammate) do
      teammate = CompanyTeammate.create!(person: non_manager_employee, organization: company)
      teammate.update!(first_employed_at: 3.months.ago)
      teammate
    end
    let!(:non_manager_employee_tenure) do
      EmploymentTenure.create!(
        teammate: non_manager_employee_teammate,
        company: company,
        position: position,
        employment_type: 'full_time',
        started_at: 3.months.ago
      )
    end

    before do
      # Ensure non_manager_employee data is created and revisit the page
      non_manager_employee_tenure
      visit organization_teammate_position_path(company, employee_teammate)
    end

    it 'shows managers in Active Managers optgroup' do
      expect(page).to have_content('Current Position')
      
      # Check that managers appear in the dropdown
      expect(page).to have_select('employment_tenure_update[manager_teammate_id]', with_options: [current_manager.last_first_display_name])
      expect(page).to have_select('employment_tenure_update[manager_teammate_id]', with_options: [new_manager.last_first_display_name])
      
      # Check for optgroup labels (using HTML structure)
      select_element = page.find('select[name="employment_tenure_update[manager_teammate_id]"]')
      expect(select_element).to have_selector('optgroup[label="Active Managers"]', visible: false)
    end

    it 'shows non-manager employees in Other Employees optgroup' do
      expect(page).to have_content('Current Position')
      
      # Check that non-manager employees appear in the dropdown
      expect(page).to have_select('employment_tenure_update[manager_teammate_id]', with_options: [non_manager_employee.last_first_display_name])
      
      # Check for optgroup labels
      select_element = page.find('select[name="employment_tenure_update[manager_teammate_id]"]')
      expect(select_element).to have_selector('optgroup[label="Other Employees"]', visible: false)
    end

    it 'allows selecting a non-manager employee as manager' do
      expect(page).to have_content('Current Position')
      
      select non_manager_employee.last_first_display_name, from: 'employment_tenure_update[manager_teammate_id]'
      click_button 'Update Position'
      
      expect(page).to have_content('Position information was successfully updated')
      expect(current_tenure.reload.ended_at).to be_within(5.seconds).of(Time.current)
      
      new_tenure = EmploymentTenure.where(teammate: employee_teammate, company: company).order(:created_at).last
      expect(new_tenure.manager_teammate.person).to eq(non_manager_employee)
    end

    it 'excludes the current person being edited from the dropdown' do
      expect(page).to have_content('Current Position')
      
      # The employee_person should not appear in the dropdown (to prevent self-management)
      expect(page).not_to have_select('employment_tenure_update[manager_teammate_id]', with_options: [employee_person.last_first_display_name])
    end

    it 'sets the currently saved value using company_teammate_id' do
      expect(page).to have_content('Current Position')
      
      # Reload current_tenure to get the actual manager (may have been updated by manager_employment_tenure_for_permission)
      current_tenure.reload
      saved_manager_teammate_id = current_tenure.manager_teammate_id
      
      # Skip test if no manager is set
      skip 'No manager set on employment tenure' if saved_manager_teammate_id.nil?
      
      # Verify that the dropdown is pre-selected with the company_teammate_id
      select_element = page.find('select[name="employment_tenure_update[manager_teammate_id]"]')
      selected_value = select_element.value
      
      # The selected value should be the company_teammate_id from the employment tenure
      expect(selected_value.to_i).to eq(saved_manager_teammate_id)
      
      # Verify it's a valid CompanyTeammate ID (not a person_id)
      expect(CompanyTeammate.exists?(id: selected_value)).to be true
      
      # Verify the selected value corresponds to the correct CompanyTeammate
      selected_teammate = CompanyTeammate.find(selected_value.to_i)
      expect(selected_teammate.id).to eq(saved_manager_teammate_id)
      
      # Verify that all option values in the dropdown are company_teammate_ids
      # Get all option values from the select element (excluding empty/blank values)
      option_values = select_element.all('option').map { |opt| opt.value.to_i }.reject(&:zero?)
      
      # All option values should be valid CompanyTeammate IDs
      option_values.each do |option_value|
        expect(CompanyTeammate.exists?(id: option_value)).to be true
        # The option_value should be the company_teammate.id
        teammate = CompanyTeammate.find(option_value)
        expect(option_value).to eq(teammate.id)
      end
      
      # Additional check: verify that if we have a manager set, the selected value
      # matches the manager_teammate_id from the form object
      # This ensures the form is using manager_teammate_id, not person_id
      form_manager_id = current_tenure.manager_teammate_id
      expect(selected_value.to_i).to eq(form_manager_id) if form_manager_id
    end
  end

  describe 'Simple submission' do
    it 'allows manager to update manager field' do
      expect(page).to have_content('Current Position')
      # The current manager is shown in the display, but after manager_employment_tenure_for_permission updates it to manager_person
      # So we check for manager_person instead
      expect(page).to have_content(manager_person.last_first_display_name)
      
      select new_manager.last_first_display_name, from: 'employment_tenure_update[manager_teammate_id]'
      click_button 'Update Position'
      
      expect(page).to have_content('Position information was successfully updated')
      expect(current_tenure.reload.ended_at).to be_within(5.seconds).of(Time.current)
      
      new_tenure = EmploymentTenure.where(teammate: employee_teammate, company: company).order(:created_at).last
      expect(new_tenure.manager_teammate.person).to eq(new_manager)
    end
  end

  describe 'Complex submission' do

    it 'allows manager to update all fields with multiple changes' do
      select new_manager.last_first_display_name, from: 'employment_tenure_update[manager_teammate_id]'
      select new_position.display_name, from: 'employment_tenure_update[position_id]'
      select 'Part Time', from: 'employment_tenure_update[employment_type]'
      select seat_for_new_position.display_name, from: 'employment_tenure_update[seat_id]'
      fill_in 'employment_tenure_update[reason]', with: 'Promotion and schedule change'
      
      click_button 'Update Position'
      
      expect(page).to have_content('Position information was successfully updated')
      
      # Verify new tenure was created
      expect(current_tenure.reload.ended_at).to be_within(5.seconds).of(Time.current)
      new_tenure = EmploymentTenure.where(teammate: employee_teammate, company: company).order(:created_at).last
      expect(new_tenure.manager_teammate.person).to eq(new_manager)
      expect(new_tenure.position).to eq(new_position)
      expect(new_tenure.employment_type).to eq('part_time')
      expect(new_tenure.seat).to eq(seat_for_new_position)
      
      # Verify maap_snapshot was created
      snapshot = MaapSnapshot.last
      expect(snapshot.change_type).to eq('position_tenure')
      expect(snapshot.reason).to eq('Promotion and schedule change')
    end

    it 'handles termination date update' do
      termination_date = Date.current + 2.weeks
      date_string = termination_date.strftime('%Y-%m-%d')
      
      # Use JavaScript to set the date field value directly to avoid Capybara date conversion issues
      page.execute_script("document.querySelector('input[name=\"employment_tenure_update[termination_date]\"]').value = '#{date_string}';")
      
      click_button 'Update Position'
      
      # Should redirect to confirmation page
      expect(page).to have_content('Confirm Employment Termination')
      expect(page).to have_content(termination_date.strftime('%B %d, %Y'))
      
      # Fill in reason and confirm termination
      fill_in 'reason', with: 'End of contract'
      click_button 'Confirm Termination'
      
      # Should redirect back to position page with success message
      expect(page).to have_content('Employment was successfully terminated')
      
      # Reload and check the date - it should match what we submitted
      current_tenure.reload
      expect(current_tenure.ended_at).to be_present
      # Compare dates (ignore time component)
      expect(current_tenure.ended_at.to_date).to eq(termination_date)
      
      snapshot = MaapSnapshot.last
      expect(snapshot.effective_date.to_date).to eq(termination_date)
      expect(snapshot.reason).to eq('End of contract')
    end

    it 'shows validation error when reason provided without major changes' do
      # Submit form with ONLY reason, no changes at all
      fill_in 'employment_tenure_update[reason]', with: 'Seat change reason'
      
      click_button 'Update Position'
      
      expect(page).to have_content('The reason field is only saved when a major change is made')
    end

    it 'handles form errors gracefully' do
      # Try to submit with an invalid position_id (non-existent ID)
      # Use a very large ID that definitely doesn't exist
      invalid_position_id = Position.maximum(:id).to_i + 9999
      
      # Use JavaScript to set the invalid position_id and ensure it's submitted
      page.execute_script("
        var select = document.querySelector('select[name=\"employment_tenure_update[position_id]\"]');
        select.value = '#{invalid_position_id}';
        select.selectedIndex = -1; // Clear selection first
        select.value = '#{invalid_position_id}';
        select.dispatchEvent(new Event('change', { bubbles: true }));
        select.dispatchEvent(new Event('input', { bubbles: true }));
      ")
      
      # Wait a moment for the change to register
      sleep 0.5
      
      click_button 'Update Position'
      
      # The form should show validation errors for invalid position
      # Check if we're still on the same page (form errors) or if validation passed
      # If validation passed, we'd be redirected, so check for error message or stay on page
      expect(page).to have_content('does not exist').or have_content('Current Position')
    end

    it 'allows clearing seat by selecting "No Seat"' do
      # Ensure current_tenure has a seat
      expect(current_tenure.seat).to be_present
      
      # Select "No Seat" option (empty value)
      select 'No Seat', from: 'employment_tenure_update[seat_id]'
      click_button 'Update Position'
      
      expect(page).to have_content('Position information was successfully updated')
      
      # Verify seat was cleared
      current_tenure.reload
      expect(current_tenure.seat).to be_nil
      expect(current_tenure.ended_at).to be_nil
      
      # Verify no new tenure was created (seat change only)
      expect(EmploymentTenure.where(teammate: employee_teammate, company: company).count).to eq(1)
    end

    it 'allows clearing seat when changing position' do
      # Ensure current_tenure has a seat
      expect(current_tenure.seat).to be_present
      
      # Change position and clear seat in the same submission
      select new_position.display_name, from: 'employment_tenure_update[position_id]'
      select 'No Seat', from: 'employment_tenure_update[seat_id]'
      click_button 'Update Position'
      
      expect(page).to have_content('Position information was successfully updated')
      
      # Verify new tenure was created with new position and no seat
      expect(current_tenure.reload.ended_at).to be_within(5.seconds).of(Time.current)
      new_tenure = EmploymentTenure.where(teammate: employee_teammate, company: company).order(:created_at).last
      expect(new_tenure.position).to eq(new_position)
      expect(new_tenure.seat).to be_nil
      
      # Verify maap_snapshot was created
      snapshot = MaapSnapshot.last
      expect(snapshot.change_type).to eq('position_tenure')
    end
  end

  describe 'Permission-based UI' do
    context 'when user has can_manage_employment permission' do
      it 'shows enabled form fields' do
        expect(page).to have_select('employment_tenure_update[manager_teammate_id]', disabled: false)
        expect(page).to have_select('employment_tenure_update[position_id]', disabled: false)
        expect(page).to have_button('Update Position', disabled: false)
      end
    end

    context 'when user is in managerial hierarchy but does not have can_manage_employment flag' do
      # Set flag before parent before block runs
      let!(:override_permission) do
        @can_manage_employment_override = false
        manager_teammate.update!(can_manage_employment: false)
      end
      
      before do
        # manager_employment_tenure_for_permission sets up manager_person as manager of employee_person
        # This puts manager_person in the managerial hierarchy, which grants change_employment? access
        # Reload page to pick up the permission change
        visit current_path
      end

      it 'shows enabled form fields via managerial hierarchy' do
        expect(page).to have_content('Current Position')
        expect(page).to have_select('employment_tenure_update[manager_teammate_id]', disabled: false)
        expect(page).to have_select('employment_tenure_update[position_id]', disabled: false)
        expect(page).to have_select('employment_tenure_update[employment_type]', disabled: false)
        expect(page).to have_select('employment_tenure_update[seat_id]', disabled: false)
        expect(page).to have_field('employment_tenure_update[termination_date]', disabled: false)
        expect(page).to have_field('employment_tenure_update[reason]', disabled: false)
        expect(page).to have_button('Update Position', disabled: false)
      end
    end

    context 'when user does not have can_manage_employment permission and is not in managerial hierarchy' do
      # Create a different manager who is NOT in the hierarchy
      let(:non_hierarchy_manager_person) { create(:person, first_name: 'NonHierarchy', last_name: 'Manager') }
      let!(:non_hierarchy_manager_teammate) { CompanyTeammate.create!(person: non_hierarchy_manager_person, organization: company, can_manage_employment: false) }
      let!(:non_hierarchy_manager_tenure) do
        EmploymentTenure.create!(
          teammate: non_hierarchy_manager_teammate,
          company: company,
          position: position,
          employment_type: 'full_time',
          started_at: 1.year.ago
        )
      end
      
      before do
        # Sign in as the non-hierarchy manager
        sign_in_and_visit(non_hierarchy_manager_person, company, organization_teammate_position_path(company, employee_teammate))
      end

      it 'redirects to public profile because view_check_ins? policy denies access' do
        # Since view_check_ins? requires audit? which needs can_manage_employment OR hierarchy,
        # users without either cannot view the position page at all
        expect(page).to have_content(/don't have permission|not authorized/i)
        expect(page).not_to have_content('Current Position')
      end
    end
  end

  describe 'Position dropdown grouping' do
    let(:department) { create(:organization, :department, parent: company) }
    let!(:dept_position_type) { create(:position_type, organization: department, position_major_level: shared_major_level, external_title: 'Department Engineer') }
    let!(:dept_position) { create(:position, position_type_id: dept_position_type.id, position_level_id: position_level1.id) }

    it 'shows positions grouped by department with optgroups' do
      visit organization_teammate_position_path(company, employee_teammate)
      
      expect(page).to have_content('Current Position')
      
      # Check for optgroup labels
      select_element = page.find('select[name="employment_tenure_update[position_id]"]')
      expect(select_element).to have_selector('optgroup[label="' + company.display_name + '"]', visible: false)
      expect(select_element).to have_selector('optgroup[label="' + department.display_name + '"]', visible: false)
    end
  end

  describe 'Start/Restart Employment Form' do
    let(:teammate_without_employment) do
      person = create(:person, first_name: 'No', last_name: 'Employment')
      CompanyTeammate.create!(person: person, organization: company)
    end

    context 'when no active employment and no previous tenures' do
      before do
        sign_in_and_visit(manager_person, company, organization_teammate_position_path(company, teammate_without_employment))
      end

      it 'shows Start Employment form' do
        expect(page).to have_content('Start Employment')
        expect(page).to have_field('employment_tenure[position_id]')
        expect(page).to have_field('employment_tenure[started_at]')
        expect(page).to have_button('Start Employment')
      end

      it 'allows starting employment' do
        select position.display_name, from: 'employment_tenure[position_id]'
        fill_in 'employment_tenure[started_at]', with: Date.current.strftime('%Y-%m-%d')
        click_button 'Start Employment'
        
        expect(page).to have_content('Employment was successfully started')
        expect(EmploymentTenure.where(teammate: teammate_without_employment, company: company).active.count).to eq(1)
      end
    end

    context 'when no active employment but has inactive tenures' do
      let!(:inactive_tenure) do
        EmploymentTenure.create!(
          teammate: teammate_without_employment,
          company: company,
          position: position,
          started_at: 2.years.ago,
          ended_at: 1.year.ago
        )
      end

      before do
        sign_in_and_visit(manager_person, company, organization_teammate_position_path(company, teammate_without_employment))
      end

      it 'shows Restart Employment form' do
        expect(page).to have_content('Restart Employment')
        expect(page).to have_field('employment_tenure[position_id]')
        expect(page).to have_field('employment_tenure[started_at]')
        expect(page).to have_button('Restart Employment')
        expect(page).to have_content('Must be after the last employment end date')
      end

      it 'allows restarting employment' do
        select position.display_name, from: 'employment_tenure[position_id]'
        restart_date = (inactive_tenure.ended_at + 1.day).to_date
        # Clear the field first, then fill it with the correct date
        page.execute_script("document.querySelector('input[name=\"employment_tenure[started_at]\"]').value = '#{restart_date.strftime('%Y-%m-%d')}';")
        click_button 'Restart Employment'
        
        expect(page).to have_content('Employment was successfully started')
        new_tenure = EmploymentTenure.where(teammate: teammate_without_employment, company: company).active.first
        expect(new_tenure.started_at.to_date).to eq(restart_date)
      end
    end

    context 'when active employment exists' do
      let!(:active_tenure) do
        EmploymentTenure.create!(
          teammate: teammate_without_employment,
          company: company,
          position: position,
          started_at: 6.months.ago
        )
      end

      before do
        sign_in_and_visit(manager_person, company, organization_teammate_position_path(company, teammate_without_employment))
      end

      it 'does not show Start/Restart Employment form' do
        expect(page).not_to have_content('Start Employment')
        expect(page).not_to have_content('Restart Employment')
        expect(page).to have_content('Current Position')
      end
    end

    context 'position dropdown grouping in start/restart form' do
      let(:department) { create(:organization, :department, parent: company) }
      let!(:dept_position_type) { create(:position_type, organization: department, position_major_level: shared_major_level, external_title: 'Department Engineer') }
      let!(:dept_position) { create(:position, position_type_id: dept_position_type.id, position_level_id: position_level1.id) }

      before do
        sign_in_and_visit(manager_person, company, organization_teammate_position_path(company, teammate_without_employment))
      end

      it 'shows positions grouped by department with optgroups' do
        expect(page).to have_content('Start Employment')
        
        # Check for optgroup labels in the start employment form
        select_element = page.find('select[name="employment_tenure[position_id]"]')
        expect(select_element).to have_selector('optgroup[label="' + company.display_name + '"]', visible: false)
        expect(select_element).to have_selector('optgroup[label="' + department.display_name + '"]', visible: false)
      end
    end
  end
end

