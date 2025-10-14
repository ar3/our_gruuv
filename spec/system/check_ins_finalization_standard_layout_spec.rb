require 'rails_helper'

RSpec.describe 'Check-Ins and Finalization Standard Layout', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager Guy') }
  let!(:manager_teammate) { create(:teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
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

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(manager_person).to receive(:can_manage_employment?).with(organization).and_return(true)
    allow(manager_person).to receive(:can_manage_employment?).and_return(true)
  end

  describe 'Check-Ins page layout' do
    it 'follows standard layout with view switcher and proper navigation' do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Check header
      expect(page).to have_content('Check-Ins for John Doe')
      expect(page).to have_content('View Mode: Manager')
      
      # Check view switcher is present
      expect(page).to have_css('.dropdown-toggle')
      
      # Open dropdown to check active state
      find('.dropdown-toggle').click
      expect(page).to have_content('Check-In Mode (Active)')
      
      # Check back link
      expect(page).to have_link('Back to Assignments')
      
      # Check view switcher options
      expect(page).to have_content('Check-In Mode')
      expect(page).to have_content('Finalization Mode')
      expect(page).to have_content('Assignment Mode')
      expect(page).to have_content('Management Mode')
    end

    it 'shows correct back link when no active position' do
      # Remove the employment tenure to simulate no active position
      employment_tenure.destroy
      
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Should show "Back to Profile" instead of "Back to Assignments"
      expect(page).to have_link('Back to Profile')
      expect(page).not_to have_link('Back to Assignments')
    end
  end

  describe 'Finalization page layout' do
    it 'follows standard layout with view switcher and proper navigation' do
      # Complete both assessments to make it ready for finalization
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      position_check_in.update!(
        employee_rating: 1,
        employee_private_notes: 'I feel I am meeting expectations',
        manager_rating: 2,
        manager_private_notes: 'John is doing great work'
      )
      position_check_in.complete_employee_side!
      position_check_in.complete_manager_side!(completed_by: manager_person)

      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      visit organization_person_finalization_path(organization, employee_person)
      
      # Check header
      expect(page).to have_content('Finalize Check-Ins for John Doe')
      expect(page).to have_content('Review ready check-ins and finalize selected ones')
      
      # Check view switcher is present
      expect(page).to have_css('.dropdown-toggle')
      
      # Open dropdown to check active state
      find('.dropdown-toggle').click
      expect(page).to have_content('Finalization Mode (Active)')
      
      # Check back link
      expect(page).to have_link('Back to Check-Ins')
      
      # Check view switcher options
      expect(page).to have_content('Check-In Mode')
      expect(page).to have_content('Finalization Mode')
      expect(page).to have_content('Assignment Mode')
      expect(page).to have_content('Management Mode')
    end

    it 'shows correct header for employee view' do
      # Complete both assessments
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      position_check_in.update!(
        employee_rating: 1,
        employee_private_notes: 'I feel I am meeting expectations',
        manager_rating: 2,
        manager_private_notes: 'John is doing great work'
      )
      position_check_in.complete_employee_side!
      position_check_in.complete_manager_side!(completed_by: manager_person)

      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
      visit organization_person_finalization_path(organization, employee_person)
      
      # Check header for employee
      expect(page).to have_content('Finalize Check-Ins for John Doe')
      expect(page).to have_content('Review your check-ins that are ready for finalization')
    end
  end

  describe 'View switcher navigation' do
    it 'shows correct view switcher options' do
      # Create a check-in so finalization page has something to show
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      position_check_in.update!(
        employee_rating: 1,
        employee_private_notes: 'I feel I am meeting expectations',
        manager_rating: 2,
        manager_private_notes: 'John is doing great work'
      )
      position_check_in.complete_employee_side!
      position_check_in.complete_manager_side!(completed_by: manager_person)

      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      
      # Test check-ins page view switcher
      visit organization_person_check_ins_path(organization, employee_person)
      find('.dropdown-toggle').click
      expect(page).to have_content('Check-In Mode (Active)')
      expect(page).to have_content('Finalization Mode')
      
      # Test finalization page view switcher
      visit organization_person_finalization_path(organization, employee_person)
      find('.dropdown-toggle').click
      expect(page).to have_content('Finalization Mode (Active)')
      expect(page).to have_content('Check-In Mode')
    end
  end
end
