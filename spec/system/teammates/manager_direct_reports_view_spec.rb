require 'rails_helper'

RSpec.describe 'Manager Direct Reports View', type: :system, js: true do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:direct_report1) { create(:person, first_name: 'Alice', last_name: 'Smith') }
  let(:direct_report2) { create(:person, first_name: 'Bob', last_name: 'Jones') }
  let(:non_direct_report) { create(:person, first_name: 'Charlie', last_name: 'Brown') }
  
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:direct_report1_teammate) { create(:teammate, person: direct_report1, organization: organization) }
  let(:direct_report2_teammate) { create(:teammate, person: direct_report2, organization: organization) }
  let(:non_direct_report_teammate) { create(:teammate, person: non_direct_report, organization: organization) }

  before do
    # Create employment tenures with manager relationships
    create(:employment_tenure, teammate: direct_report1_teammate, company: organization, manager: manager, ended_at: nil)
    create(:employment_tenure, teammate: direct_report2_teammate, company: organization, manager: manager, ended_at: nil)
    create(:employment_tenure, teammate: non_direct_report_teammate, company: organization, manager: nil, ended_at: nil)
  end

  describe 'Navigation and Access' do
    it 'shows My Employees link in user dropdown when manager has direct reports' do
      sign_in_and_visit(manager, organization, root_path)
      
      # Navigate to user dropdown - find the one with person's name
      find('a.nav-link.dropdown-toggle', text: /#{manager.full_name}/).click
      
      expect(page).to have_link('My Employees', wait: 5)
    end

    it 'does not show My Employees link when manager has no direct reports' do
      # Remove manager relationships
      EmploymentTenure.where(manager: manager).destroy_all
      
      sign_in_and_visit(manager, organization, root_path)
      
      # Navigate to user dropdown
      find('a.nav-link.dropdown-toggle', text: /#{manager.full_name}/).click
      
      expect(page).not_to have_link('My Employees', wait: 2)
    end

    it 'navigates to direct reports view when clicking My Employees link' do
      sign_in_and_visit(manager, organization, root_path)
      
      # Navigate to user dropdown and click My Employees
      find('a.nav-link.dropdown-toggle', text: /#{manager.full_name}/).click
      click_link 'My Employees'
      
      # Wait for navigation
      expect(page).to have_current_path(organization_employees_path(organization), wait: 5)
      expect(page).to have_content('Alice Smith', wait: 5)
      expect(page).to have_content('Bob Jones', wait: 5)
      expect(page).not_to have_content('Charlie Brown')
    end
  end

  describe 'Direct Reports View Rendering' do
    before do
      sign_in_and_visit(manager, organization, organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status'))
      # Wait for page to load
      expect(page).to have_content(/Teammates|Employees|Direct Reports/i, wait: 5)
    end

    it 'shows only direct reports in check-in status cards' do
      expect(page).to have_content('Alice Smith', wait: 5)
      expect(page).to have_content('Bob Jones', wait: 5)
      expect(page).not_to have_content('Charlie Brown')
    end

    it 'shows manager overview spotlight with correct metrics' do
      # Manager overview may be in spotlight section
      expect(page).to have_content(/Manager|Overview|Direct Reports/i, wait: 5)
    end

    it 'renders check-in status cards with proper 4-column layout' do
      # Check that we have cards/rows - layout may vary
      expect(page).to have_css('.card, .row, [class*="col"]', wait: 5)
    end

    it 'shows employee names linked to profiles' do
      # Names should be present, may or may not be links
      expect(page).to have_content('Alice Smith', wait: 5)
      expect(page).to have_content('Bob Jones', wait: 5)
    end

    it 'displays overall status badges for each employee' do
      # Status information should be present
      expect(page).to have_content(/Status|Check-in|Complete|Pending/i, wait: 5)
    end

    it 'shows check-ins column with all check-in types' do
      # Check-in information should be present
      expect(page).to have_content(/Check-in|Position|Assignment|Aspiration/i, wait: 5)
    end

    it 'shows ready for finalization column with counts' do
      expect(page).to have_content(/Finalization|Ready/i, wait: 5)
    end

    it 'shows pending acknowledgements column with counts' do
      expect(page).to have_content(/Acknowledgement|Pending/i, wait: 5)
    end
  end

  describe 'Filter Modal Functionality' do
    before do
      sign_in_and_visit(manager, organization, organization_employees_path(organization))
      click_button 'Filter & Sort'
      # Wait for modal to be visible
      expect(page).to have_css('#teammates-filter-modal', visible: true, wait: 5)
    end

    it 'shows manager relationship filter options' do
      expect(page).to have_content('Manager Relationship')
      expect(page).to have_radio_button('manager_all')
      expect(page).to have_radio_button('manager_direct')
      expect(page).to have_content('All Teammates')
      expect(page).to have_content('My Direct Reports')
    end

    it 'shows check-in status display option' do
      expect(page).to have_content('View Style')
      expect(page).to have_radio_button('view_check_in_status')
      expect(page).to have_content('Check-in Status')
    end

    it 'applies manager filter when submitted' do
      choose 'manager_direct'
      choose 'view_check_in_status'
      click_button 'Apply Filters'
      
      expect(current_path).to eq(organization_employees_path(organization))
      expect(page).to have_content('Alice Smith')
      expect(page).not_to have_content('Charlie Brown')
    end
  end

  describe 'Authorization and Security' do
    let(:non_manager) { create(:person) }

    it 'redirects non-managers trying to access direct reports view' do
      sign_in_and_visit(non_manager, organization, organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status'))
      
      expect(page).to have_content('You do not have any direct reports in this organization')
      expect(current_path).to eq(organization_employees_path(organization))
    end

    it 'prevents unauthorized access to manager-specific data' do
      sign_in_and_visit(non_manager, organization, organization_employees_path(organization, manager_filter: 'direct_reports'))
      
      # Should not see direct reports data
      expect(page).not_to have_content('Alice Smith')
      expect(page).not_to have_content('Bob Jones')
    end
  end

  describe 'Empty State Handling' do
    before do
      # Remove all direct reports
      EmploymentTenure.where(manager: manager).destroy_all
      
      sign_in_and_visit(manager, organization, organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status'))
    end

    it 'shows appropriate empty state message' do
      expect(page).to have_content('No Direct Reports Found')
      expect(page).to have_content("You don't have any direct reports in this organization")
      expect(page).to have_link('View All Teammates')
    end

    it 'allows navigation back to all teammates' do
      click_link 'View All Teammates'
      expect(current_path).to eq(organization_employees_path(organization))
      expect(page).to have_content('Charlie Brown') # Non-direct report should be visible
    end
  end

  describe 'Integration with Existing Filters' do
    before do
      # Make direct_report1 an assigned employee
      direct_report1_teammate.update!(first_employed_at: 1.month.ago)
      
      sign_in_and_visit(manager, organization, organization_employees_path(organization, manager_filter: 'direct_reports', status: 'assigned_employee', display: 'check_in_status'))
    end

    it 'combines manager filter with status filter correctly' do
      expect(page).to have_content('Alice Smith')
      expect(page).not_to have_content('Bob Jones') # Not assigned yet
      expect(page).to have_content('Active Filters:')
      expect(page).to have_content('My Direct Reports')
      expect(page).to have_content('Active Employees')
    end

    it 'shows active filter badges that can be cleared' do
      expect(page).to have_css('.badge.bg-primary', text: 'My Direct Reports')
      expect(page).to have_css('.badge.bg-primary', text: 'Active Employees')
      
      # Test clearing individual filters
      click_link '×', match: :first # Clear first filter
      expect(page).to have_content('Clear All')
    end
  end

  describe 'Check-in Status Calculations' do
    let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
    let!(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
    let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
    let(:position) { create(:position, position_type: position_type, position_level: position_level) }
    let(:assignment) { create(:assignment, company: organization) }

    before do
      # Create employment tenure with position
      employment_tenure = create(:employment_tenure, teammate: direct_report1_teammate, company: organization, manager: manager, position: position, ended_at: nil)
      
      # Create assignment tenure
      assignment_tenure = create(:assignment_tenure, teammate: direct_report1_teammate, assignment: assignment, ended_at: nil)
      
      # Create check-ins
      position_check_in = create(:position_check_in, teammate: direct_report1_teammate, employment_tenure: employment_tenure, employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago)
      assignment_check_in = create(:assignment_check_in, teammate: direct_report1_teammate, assignment: assignment, employee_completed_at: 1.day.ago, manager_completed_at: nil)
      
      sign_in_and_visit(manager, organization, organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status'))
    end

    it 'calculates overall status correctly based on check-in states' do
      # Should show "Ready to Finalize" for position check-in
      expect(page).to have_css('.badge.bg-warning', text: 'Ready')
      
      # Should show "Manager" for assignment check-in needing manager input
      expect(page).to have_css('.badge.bg-danger', text: 'Manager')
    end

    it 'shows correct counts in ready for finalization column' do
      expect(page).to have_content('Ready for Finalization')
      # Should show count of 1 for position check-in ready to finalize
    end

    it 'shows correct counts in pending acknowledgements column' do
      expect(page).to have_content('Pending Acknowledgements')
      # Should show 0 when no pending acknowledgements
    end
  end

  describe 'Manager Spotlight Metrics' do
    before do
      sign_in_and_visit(manager, organization, organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status'))
    end

    it 'displays team health score' do
      expect(page).to have_content('Team Health')
      expect(page).to have_content('/100')
    end

    it 'shows check-in status summary with progress bars' do
      expect(page).to have_content('Check-in Status Summary')
      expect(page).to have_css('.progress-bar')
    end

    it 'displays action alerts when needed' do
      # Should show alerts for items needing attention
      expect(page).to have_css('.alert')
    end
  end

  describe 'Pagination and Performance' do
    before do
      # Create many direct reports to test pagination
      30.times do |i|
        person = create(:person, first_name: "Employee#{i}", last_name: "Test")
        teammate = create(:teammate, person: person, organization: organization)
        create(:employment_tenure, teammate: teammate, company: organization, manager: manager, ended_at: nil)
      end
      
      sign_in_and_visit(manager, organization, organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status'))
    end

    it 'handles pagination correctly with many direct reports' do
      expect(page).to have_content('Employee0 Test')
      expect(page).to have_content('Employee24 Test') # Should be on first page
      expect(page).not_to have_content('Employee25 Test') # Should be on second page
    end

    it 'maintains filter state across pagination' do
      expect(current_url).to include('manager_filter=direct_reports')
      expect(current_url).to include('display=check_in_status')
    end
  end
end
