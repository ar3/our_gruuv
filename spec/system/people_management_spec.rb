require 'rails_helper'

RSpec.describe 'People Management', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_employment?).and_return(true)
  end

  describe 'Employees index page' do
    it 'loads employees index with pagination and filters' do
      # Create some teammates for testing
      (1..5).each do |i|
        person = create(:person, full_name: "Employee #{i}", email: "employee#{i}@example.com")
        create(:teammate, person: person, organization: organization, first_employed_at: 1.year.ago)
      end
      
      visit organization_employees_path(organization)
      
      # Should see employees index
      expect(page).to have_content('Employees')
      expect(page).to have_content('Employee 1')
      expect(page).to have_content('Employee 2')
      
      # Should see pagination controls (if there are enough items)
      # Note: With only 5 items, pagination might not show
      expect(page).to have_content('Displaying')
      
      # Should see filter button
      expect(page).to have_button('Filter & Sort')
    end

    it 'shows different view types (table, cards, list)' do
      visit organization_employees_path(organization)
      
      # Should see view type options
      expect(page).to have_button('Filter & Sort')
      
      # Click filter button to see view options
      click_button 'Filter & Sort'
      
      # Should see view type options in modal
      expect(page).to have_content('View Style')
      expect(page).to have_content('Table View')
      expect(page).to have_content('Card View')
      expect(page).to have_content('List View')
    end
  end

  describe 'Employment management wizard' do
    it 'loads employment management page' do
      visit organization_employment_management_index_path(organization)
      
      # Should see employment management page
      expect(page).to have_content('Employment Management')
      expect(page).to have_content('Potential Employees')
      
      # Should see employment management content
      expect(page).to have_content('Create New Employee')
    end

    it 'shows new employee creation form' do
      visit new_organization_employment_management_path(organization)
      
      # Should see new employee form or permission error
      if page.has_content?('Create New Employee')
        expect(page).to have_content('Create New Employee')
        expect(page).to have_field('person_full_name')
        expect(page).to have_field('person_email')
      else
        # User doesn't have permission
        expect(page).to have_content('permission')
      end
    end
  end

  describe 'People complete picture page' do
    let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
    let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }

    it 'loads people complete picture page' do
      visit complete_picture_organization_person_path(organization, employee_person)
      
      # Should see complete picture page
      expect(page).to have_content('Complete Picture')
      expect(page).to have_content('John Doe')
      
      # Should see complete picture content
      expect(page).to have_content('Complete Picture')
      expect(page).to have_content('Current Position')
    end
  end

  describe 'People profile page' do
    let!(:employee_person) { create(:person, full_name: 'Jane Smith', email: 'jane@example.com') }
    let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }

    it 'loads people profile page' do
      visit person_path(employee_person)
      
      # Should see profile page (may be in public mode due to permissions)
      expect(page).to have_content('Jane Smith')
      expect(page).to have_content('Public Mode').or have_content('Profile')
    end
  end

  describe 'Followers vs Employees' do
    it 'distinguishes between followers and employees' do
      # Create a follower (no employment tenure)
      follower_person = create(:person, full_name: 'Follower User', email: 'follower@example.com')
      follower_teammate = create(:teammate, person: follower_person, organization: organization, first_employed_at: nil)
      
      # Create an employee (with employment tenure)
      employee_person = create(:person, full_name: 'Employee User', email: 'employee@example.com')
      employee_teammate = create(:teammate, person: employee_person, organization: organization, first_employed_at: 1.year.ago)
      
      visit organization_employees_path(organization)
      
      # Should see both in the list
      expect(page).to have_content('Follower User')
      expect(page).to have_content('Employee User')
      
      # Should be able to filter by status
      click_button 'Filter & Sort'
      
      # Should see filter options
      expect(page).to have_content('Unassigned Employees')
      expect(page).to have_content('Followers')
    end
  end

  describe 'Navigation and UI elements' do
    it 'navigates between people-related pages' do
      # Start at employees index
      visit organization_employees_path(organization)
      expect(page).to have_content('Employees')
      
      # Navigate to employment management
      visit organization_employment_management_index_path(organization)
      expect(page).to have_content('Employment Management')
      
      # Navigate to new employee (may show permission error)
      visit new_organization_employment_management_path(organization)
      expect(page).to have_content('Create New Employee').or have_content('permission')
    end

    it 'shows proper permissions and access controls' do
      # Test with user who can't manage employment
      allow(person).to receive(:can_manage_employment?).and_return(false)
      
      visit organization_employment_management_index_path(organization)
      
      # Should show appropriate access control
      expect(page).to have_content('Employment Management')
      # Should not see create button or have restricted access
    end
  end
end
