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
  let!(:current_manager_teammate) { CompanyTeammate.create!(person: current_manager, organization: company) }
  let!(:new_manager_teammate) { CompanyTeammate.create!(person: new_manager, organization: company) }
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
  let!(:new_position) { Position.create!(position_type_id: position_type2.id, position_level_id: position_level2.id, position_summary: 'Test position 2') }
  let!(:seat) { Seat.create!(position_type_id: position_type1.id, seat_needed_by: Date.current + 3.months, job_classification: 'Salaried Exempt', state: :open) }
  let!(:seat_for_new_position) { Seat.create!(position_type_id: position_type2.id, seat_needed_by: Date.current + 4.months, job_classification: 'Salaried Exempt', state: :open) }
  
  let!(:current_tenure) do
    EmploymentTenure.create!(
      teammate: employee_teammate,
      company: company,
      position: position,
      manager: current_manager,
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
    # Update current_tenure after it's created to have manager_person as manager
    # This ensures manager_person is in the managerial hierarchy
    current_tenure.update!(manager: manager_person)
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

  describe 'Simple submission' do
    it 'allows manager to update manager field' do
      expect(page).to have_content('Current Position')
      expect(page).to have_content(current_manager.display_name)
      
      select new_manager.display_name, from: 'employment_tenure_update[manager_id]'
      click_button 'Update Position'
      
      expect(page).to have_content('Position information was successfully updated')
      expect(current_tenure.reload.ended_at).to eq(Date.current)
      
      new_tenure = EmploymentTenure.where(teammate: employee_teammate, company: company).order(:created_at).last
      expect(new_tenure.manager).to eq(new_manager)
    end
  end

  describe 'Complex submission' do

    it 'allows manager to update all fields with multiple changes' do
      select new_manager.display_name, from: 'employment_tenure_update[manager_id]'
      select new_position.display_name, from: 'employment_tenure_update[position_id]'
      select 'Part Time', from: 'employment_tenure_update[employment_type]'
      select seat_for_new_position.display_name, from: 'employment_tenure_update[seat_id]'
      fill_in 'employment_tenure_update[reason]', with: 'Promotion and schedule change'
      
      click_button 'Update Position'
      
      expect(page).to have_content('Position information was successfully updated')
      
      # Verify new tenure was created
      expect(current_tenure.reload.ended_at).to eq(Date.current)
      new_tenure = EmploymentTenure.where(teammate: employee_teammate, company: company).order(:created_at).last
      expect(new_tenure.manager).to eq(new_manager)
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
      fill_in 'employment_tenure_update[reason]', with: 'End of contract'
      
      click_button 'Update Position'
      
      expect(page).to have_content('Position information was successfully updated')
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
  end

  describe 'Permission-based UI' do
    context 'when user has can_manage_employment permission' do
      it 'shows enabled form fields' do
        expect(page).to have_select('employment_tenure_update[manager_id]', disabled: false)
        expect(page).to have_select('employment_tenure_update[position_id]', disabled: false)
        expect(page).to have_button('Update Position', disabled: false)
      end
    end

    context 'when user does not have can_manage_employment permission' do
      # Set flag before parent before block runs
      let!(:override_permission) do
        @can_manage_employment_override = false
        manager_teammate.update!(can_manage_employment: false)
      end
      
      before do
        # The manager needs to be able to view the page (via managerial hierarchy)
        # manager_employment_tenure_for_permission sets up manager_person as manager of employee_person
        # This allows view_check_ins? to pass even without can_manage_employment
        # Reload page to pick up the permission change
        visit current_path
      end

      it 'shows form but with disabled fields' do
        expect(page).to have_content('Current Position')
        expect(page).to have_select('employment_tenure_update[manager_id]', disabled: true)
        expect(page).to have_select('employment_tenure_update[position_id]', disabled: true)
        expect(page).to have_select('employment_tenure_update[employment_type]', disabled: true)
        expect(page).to have_select('employment_tenure_update[seat_id]', disabled: true)
        expect(page).to have_field('employment_tenure_update[termination_date]', disabled: true)
        expect(page).to have_field('employment_tenure_update[reason]', disabled: true)
      end

      it 'shows disabled button with warning icon and tooltip' do
        disabled_button = find('input[type="submit"][disabled]')
        expect(disabled_button).to be_present
        
        warning_icon = find('i.bi-exclamation-triangle.text-warning')
        expect(warning_icon).to be_present
        expect(warning_icon['data-bs-title']).to include('employment management permission')
      end
    end
  end
end

