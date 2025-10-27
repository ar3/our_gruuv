require 'rails_helper'

RSpec.describe 'Finalization Table Layout', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager Guy') }
  let!(:manager_teammate) { create(:teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  
  let!(:assignment1) { create(:assignment, company: organization, title: 'Frontend Development') }
  let!(:assignment2) { create(:assignment, company: organization, title: 'Backend Development') }
  let!(:aspiration) { create(:aspiration, organization: organization, name: 'Technical Leadership') }
  
  let!(:manager_employment_tenure) do
    create(:employment_tenure,
      teammate: manager_teammate,
      position: position,
      company: organization,
      started_at: 2.years.ago
    )
  end
  
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
  
  let!(:assignment_check_in1) do
    check_in = AssignmentCheckIn.create!(
      teammate: employee_teammate,
      assignment: assignment1,
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
  
  let!(:assignment_check_in2) do
    check_in = AssignmentCheckIn.create!(
      teammate: employee_teammate,
      assignment: assignment2,
      check_in_started_on: Date.current,
      employee_rating: 'exceeding',
      manager_rating: 'meeting',
      employee_private_notes: 'Learning fast',
      manager_private_notes: 'Solid foundation',
      employee_completed_at: 1.day.ago,
      manager_completed_at: 1.day.ago,
      actual_energy_percentage: 80
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
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
  end

  describe 'Table structure' do
    it 'shows section headers for Position, Assignments, and Aspirations' do
      visit organization_person_finalization_path(organization, employee_person)
      
      expect(page).to have_content('POSITION/OVERALL')
      expect(page).to have_content('ASSIGNMENTS/OUTCOMES')
      expect(page).to have_content('ASPIRATIONS/VALUES')
    end
    
    it 'displays position data in table format' do
      visit organization_person_finalization_path(organization, employee_person)
      
      within('table', text: 'Position') do
        expect(page).to have_css('th', text: 'Name')
        expect(page).to have_css('th', text: 'Employee Check-in')
        expect(page).to have_css('th', text: 'Manager Check-in')
        expect(page).to have_css('th', text: 'Final Notes')
        expect(page).to have_css('th', text: 'Final Rating')
        expect(page).to have_css('th', text: 'Finalize?')
        
        expect(page).to have_content(position.display_name)
        expect(page).to have_content('I feel I am meeting expectations')
        expect(page).to have_content('John is doing great work')
      end
    end
    
    it 'displays assignment data in table format' do
      visit organization_person_finalization_path(organization, employee_person)
      
      within('table', text: 'Assignment') do
        expect(page).to have_css('th', text: 'Name')
        expect(page).to have_css('th', text: 'Employee Check-in')
        expect(page).to have_css('th', text: 'Manager Check-in')
        expect(page).to have_css('th', text: 'Final Notes')
        expect(page).to have_css('th', text: 'Final Values')
        expect(page).to have_css('th', text: 'Finalize?')
        
        expect(page).to have_content('Frontend Development')
        expect(page).to have_content('Backend Development')
        expect(page).to have_content('75%')
        expect(page).to have_content('80%')
      end
    end
    
    it 'displays aspiration data in table format' do
      visit organization_person_finalization_path(organization, employee_person)
      
      within('table', text: 'Aspiration') do
        expect(page).to have_css('th', text: 'Name')
        expect(page).to have_css('th', text: 'Employee Check-in')
        expect(page).to have_css('th', text: 'Manager Check-in')
        expect(page).to have_css('th', text: 'Final Notes')
        expect(page).to have_css('th', text: 'Final Rating')
        expect(page).to have_css('th', text: 'Finalize?')
        
        expect(page).to have_content('Technical Leadership')
      end
    end
  end
  
  describe 'Individual finalization checkboxes' do
    it 'has unchecked checkboxes for each check-in by default' do
      visit organization_person_finalization_path(organization, employee_person)
      
      # Position checkbox
      position_checkbox = page.find("input[name*='position_check_in'][name*='finalize']")
      expect(position_checkbox).not_to be_checked
      
      # Assignment checkboxes
      assignment_checkboxes = page.all("input[name*='assignment_check_ins'][name*='finalize']")
      expect(assignment_checkboxes.count).to eq(2)
      assignment_checkboxes.each do |checkbox|
        expect(checkbox).not_to be_checked
      end
      
      # Aspiration checkbox
      aspiration_checkbox = page.find("input[name*='aspiration_check_ins'][name*='finalize']")
      expect(aspiration_checkbox).not_to be_checked
    end
    
    it 'only finalizes selected check-ins when submit is clicked' do
      visit organization_person_finalization_path(organization, employee_person)
      
      # Check only position and first assignment
      check("input[name*='position_check_in'][name*='finalize']")
      check("input[name*='assignment_check_ins'][name*='finalize'][value='#{assignment_check_in1.id}']")
      
      # Fill in the final rating and notes for checked items only
      select '🔵 Meeting - Meeting expectations', from: "select[name*='position_check_in'][name*='official_rating']"
      fill_in "textarea[name*='position_check_in'][name*='shared_notes']", with: 'Position final notes'
      
      select '🟢 Exceeding', from: "select[name*='assignment_check_ins'][name*='#{assignment_check_in1.id}'][name*='official_rating']"
      fill_in "textarea[name*='assignment_check_ins'][name*='#{assignment_check_in1.id}'][name*='shared_notes']", with: 'Assignment final notes'
      
      click_button 'Finalize Selected Check-Ins'
      
      expect(page).to have_content('finalized successfully')
      expect(PositionCheckIn.find(position_check_in.id).official_check_in_completed_at).to be_present
      expect(AssignmentCheckIn.find(assignment_check_in1.id).official_check_in_completed_at).to be_present
      expect(AssignmentCheckIn.find(assignment_check_in2.id).official_check_in_completed_at).to be_nil
      expect(AspirationCheckIn.find(aspiration_check_in.id).official_check_in_completed_at).to be_nil
    end
  end
  
  describe 'Incomplete check-ins display' do
    let!(:incomplete_assignment) { create(:assignment, company: organization, title: 'Incomplete Task') }
    let!(:incomplete_assignment_check_in) do
      check_in = AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: incomplete_assignment,
        check_in_started_on: Date.current,
        employee_rating: 'meeting',
        employee_private_notes: 'Working on it',
        employee_completed_at: 1.day.ago,
        # manager not completed
        manager_completed_at: nil
      )
      check_in
    end
    
    it 'shows read-only row for incomplete check-ins with status message' do
      visit organization_person_finalization_path(organization, employee_person)
      
      within('table', text: 'Assignment') do
        expect(page).to have_content('Waiting for Manager')
        expect(page).to have_css('td[colspan="6"]', text: /employee.*completed.*manager.*not/i)
      end
    end
  end
end
