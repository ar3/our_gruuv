require 'rails_helper'

RSpec.describe 'Finalization Employee View', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager Guy') }
  let!(:manager_teammate) { create(:teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  
  let!(:assignment) { create(:assignment, company: organization, title: 'Frontend Development') }
  let!(:aspiration) { create(:aspiration, organization: organization, name: 'Technical Leadership') }
  
  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      position: position,
      company: organization,
      manager: manager_person,
      started_at: 1.year.ago
    )
  end
  
  let!(:position_check_in) do
    check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
    check_in.update!(
      employee_rating: 1,
      employee_private_notes: 'I feel I am meeting expectations',
      manager_rating: 2,
      manager_private_notes: 'John is doing great work'
    )
    check_in.complete_employee_side!
    check_in.complete_manager_side!(completed_by: manager_person)
    check_in
  end
  
  let!(:assignment_check_in) do
    check_in = AssignmentCheckIn.create!(
      teammate: employee_teammate,
      assignment: assignment,
      check_in_started_on: Date.current,
      employee_rating: 'meeting',
      manager_rating: 'exceeding',
      employee_private_notes: 'Good progress',
      manager_private_notes: 'Excellent work',
      employee_completed_at: 1.day.ago,
      manager_completed_at: 1.day.ago,
      actual_energy_percentage: 75
    )
    check_in
  end
  
  let!(:aspiration_check_in) do
    check_in = AspirationCheckIn.create!(
      teammate: employee_teammate,
      aspiration: aspiration,
      check_in_started_on: Date.current,
      employee_rating: 'meeting',
      manager_rating: 'exceeding',
      employee_private_notes: 'Building skills',
      manager_private_notes: 'Shows leadership',
      employee_completed_at: 1.day.ago,
      manager_completed_at: 1.day.ago
    )
    check_in
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(manager_person).to receive(:can_manage_employment?).with(organization).and_return(true)
    allow(manager_person).to receive(:can_manage_employment?).and_return(true)
    allow(employee_person).to receive(:can_manage_employment?).with(organization).and_return(false)
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_person!).and_return(true)
  end

  describe 'Employee view shows same tables as manager view' do
    it 'displays all section headers' do
      visit organization_person_finalization_path(organization, employee_person)
      
      expect(page).to have_content('POSITION/OVERALL')
      expect(page).to have_content('ASSIGNMENTS/OUTCOMES')
      expect(page).to have_content('ASPIRATIONS/VALUES')
    end
    
    it 'shows position data' do
      visit organization_person_finalization_path(organization, employee_person)
      
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('I feel I am meeting expectations')
      expect(page).to have_content('John is doing great work')
    end
    
    it 'shows assignment data' do
      visit organization_person_finalization_path(organization, employee_person)
      
      expect(page).to have_content('Frontend Development')
      expect(page).to have_content('Good progress')
      expect(page).to have_content('Excellent work')
      expect(page).to have_content('75%')
    end
    
    it 'shows aspiration data' do
      visit organization_person_finalization_path(organization, employee_person)
      
      expect(page).to have_content('Technical Leadership')
      expect(page).to have_content('Building skills')
      expect(page).to have_content('Shows leadership')
    end
  end
  
  describe 'Employee view shows disabled controls' do
    it 'shows "Waiting for manager to set" for final notes' do
      visit organization_person_finalization_path(organization, employee_person)
      
      # Should see "Waiting for manager to set" message
      expect(page).to have_content('Waiting for manager to set', count: 6) # 2 per check-in (notes + rating)
    end
    
    it 'shows disabled checkboxes with "Manager only" label' do
      visit organization_person_finalization_path(organization, employee_person)
      
      checkboxes = page.all('input[name*="finalize"][disabled]')
      expect(checkboxes.count).to eq(3) # One for each check-in
      
      expect(page).to have_content('(Manager only)', count: 3)
    end
    
    it 'shows disabled submit button with warning message' do
      visit organization_person_finalization_path(organization, employee_person)
      
      submit_button = find('input[type="submit"][disabled]')
      expect(submit_button).to be_disabled
      
      expect(page).to have_content('Your manager will finalize these check-ins')
    end
    
    it 'does not show editable form fields' do
      visit organization_person_finalization_path(organization, employee_person)
      
      # Should not have any enabled textareas or selects for finalization fields
      enabled_textareas = page.all('textarea[name*="shared_notes"]:not([disabled])')
      enabled_selects = page.all('select[name*="official_rating"]:not([disabled])')
      
      expect(enabled_textareas).to be_empty
      expect(enabled_selects).to be_empty
    end
  end
  
  describe 'Employee view does not allow finalization' do
    it 'form cannot be submitted' do
      visit organization_person_finalization_path(organization, employee_person)
      
      # Try to submit - button should be disabled
      submit_button = find('input[type="submit"]')
      expect(submit_button).to be_disabled
      
      # Even if we could submit, form would have no finalize flags
      # so nothing would be finalized (this is tested at controller level)
    end
  end
end
