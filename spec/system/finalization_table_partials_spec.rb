require 'rails_helper'

RSpec.describe 'Finalization Table Partials', type: :system, critical: true do
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
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_person!).and_return(true)
  end

  it 'renders all table partials without errors' do
    visit organization_person_finalization_path(organization, employee_person)
    
    # Should render without ActionView::MissingTemplate errors
    expect(page).to have_content('Finalize Check-Ins for John Doe')
    expect(page).to have_content('POSITION/OVERALL')
    expect(page).to have_content('ASSIGNMENTS/OUTCOMES')
    expect(page).to have_content('ASPIRATIONS/VALUES')
  end
  
  it 'displays position finalization row' do
    visit organization_person_finalization_path(organization, employee_person)
    
    # Check that position data is displayed - the position name should be in the table
    expect(page).to have_content('POSITION/OVERALL')
    expect(page).to have_content('Software Engineer')
    expect(page).to have_content('I feel I am meeting expectations')
    expect(page).to have_content('John is doing great work')
  end
  
  it 'displays assignment finalization row' do
    visit organization_person_finalization_path(organization, employee_person)
    
    # Check that assignment data is displayed
    expect(page).to have_content('ASSIGNMENTS/OUTCOMES')
    expect(page).to have_content('Frontend Development')
  end
  
  it 'displays aspiration finalization row' do
    visit organization_person_finalization_path(organization, employee_person)
    
    # Check that aspiration data is displayed
    expect(page).to have_content('ASPIRATIONS/VALUES')
    expect(page).to have_content('Technical Leadership')
  end
  
  it 'shows finalize checkboxes unchecked by default' do
    visit organization_person_finalization_path(organization, employee_person)
    
    # All checkboxes should be unchecked
    checkboxes = page.all('input[name*="finalize"]', visible: false)
    checkboxes.each do |checkbox|
      expect(checkbox).not_to be_checked
    end
  end
end
