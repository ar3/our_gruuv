require 'rails_helper'

RSpec.describe 'Assignment Selection', type: :system do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:position_type) { create(:position_type, organization: organization) }
  let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:manager) { create(:person, og_admin: true) }
  
  let!(:manager_employment) { create(:employment_tenure, teammate: create(:teammate, person: manager, organization: organization), position: position, started_at: 2.years.ago, ended_at: nil) }
  let!(:employment_tenure) do
    tenure = create(:employment_tenure, teammate: teammate, position: position, manager: manager, started_at: 1.year.ago, ended_at: nil)
    tenure.update!(position: position) # Ensure it uses the correct position
    tenure
  end
  
  let!(:required_assignment) { create(:assignment, company: organization, title: 'Required Assignment') }
  let!(:optional_assignment1) { create(:assignment, company: organization, title: 'Optional Assignment 1') }
  let!(:optional_assignment2) { create(:assignment, company: organization, title: 'Optional Assignment 2') }
  
  let!(:position_assignment) { create(:position_assignment, position: position, assignment: required_assignment) }

  before do
    sign_in_as(manager)
  end

  describe 'visiting the assignment selection page' do
    it 'displays all assignments with checkboxes' do
      visit assignment_selection_organization_person_path(organization, person)
      
      expect(page).to have_content('Select Assignments')
      expect(page).to have_content('Required Assignment')
      expect(page).to have_content('Optional Assignment 1')
      expect(page).to have_content('Optional Assignment 2')
      
      # All assignments should have checkboxes (some may be disabled)
      expect(page).to have_css("input[type='checkbox'][id='assignment_ids_#{required_assignment.id}']")
      expect(page).to have_css("input[type='checkbox'][id='assignment_ids_#{optional_assignment1.id}']")
      expect(page).to have_css("input[type='checkbox'][id='assignment_ids_#{optional_assignment2.id}']")
    end

    it 'auto-checks and disables required assignments' do
      visit assignment_selection_organization_person_path(organization, person)
      
      checkbox = find_field("assignment_ids_#{required_assignment.id}", disabled: true)
      expect(checkbox).to be_checked
      expect(checkbox).to be_disabled
      
      expect(page).to have_content('Required for position')
    end

    it 'auto-checks and disables assignments with active tenures' do
      create(:assignment_tenure, teammate: teammate, assignment: optional_assignment1, started_at: 1.month.ago, ended_at: nil)
      
      visit assignment_selection_organization_person_path(organization, person)
      
      checkbox = find_field("assignment_ids_#{optional_assignment1.id}", disabled: true)
      expect(checkbox).to be_checked
      expect(checkbox).to be_disabled
      
      expect(page).to have_content('Already assigned')
    end

    it 'allows checking optional assignments without tenures' do
      visit assignment_selection_organization_person_path(organization, person)
      
      checkbox = find_field("assignment_ids_#{optional_assignment2.id}")
      expect(checkbox).not_to be_checked
      expect(checkbox).not_to be_disabled
    end
  end

  describe 'selecting and saving assignments' do
    it 'creates assignment tenures and redirects to check-ins' do
      visit assignment_selection_organization_person_path(organization, person)
      
      check "assignment_ids_#{optional_assignment1.id}"
      check "assignment_ids_#{optional_assignment2.id}"
      
      click_button 'Save Assignments'
      
      expect(page).to have_current_path(organization_person_check_ins_path(organization, person))
      # Check for toast element in DOM (may not be visible immediately due to JS)
      expect(page).to have_css('.toast', text: 'Assignments updated successfully', visible: :hidden)
      
      # Verify tenures were created
      tenure1 = AssignmentTenure.find_by(teammate: teammate, assignment: optional_assignment1)
      tenure2 = AssignmentTenure.find_by(teammate: teammate, assignment: optional_assignment2)
      
      expect(tenure1).to be_present
      expect(tenure1.started_at).to eq(Date.current)
      expect(tenure1.anticipated_energy_percentage).to eq(0)
      
      expect(tenure2).to be_present
      expect(tenure2.started_at).to eq(Date.current)
      expect(tenure2.anticipated_energy_percentage).to eq(0)
    end

    it 'shows newly assigned assignments on check-ins page' do
      visit assignment_selection_organization_person_path(organization, person)
      
      check "assignment_ids_#{optional_assignment1.id}"
      click_button 'Save Assignments'
      
      expect(page).to have_current_path(organization_person_check_ins_path(organization, person))
      expect(page).to have_content('Optional Assignment 1')
      expect(page).not_to have_content('No assignments available to do a check-in on')
    end

    it 'handles saving with no new selections' do
      visit assignment_selection_organization_person_path(organization, person)
      
      click_button 'Save Assignments'
      
      expect(page).to have_current_path(organization_person_check_ins_path(organization, person))
    end
  end

  describe 'navigation' do
    it 'has a back link to check-ins page' do
      visit assignment_selection_organization_person_path(organization, person)
      
      expect(page).to have_link('Back to Check-Ins', href: organization_person_check_ins_path(organization, person))
    end

    it 'has a cancel button that returns to check-ins' do
      visit assignment_selection_organization_person_path(organization, person)
      
      click_link 'Cancel'
      
      expect(page).to have_current_path(organization_person_check_ins_path(organization, person))
    end
  end

  describe 'when person has no employment' do
    before do
      employment_tenure.destroy
    end

    it 'shows message about needing employment first' do
      visit assignment_selection_organization_person_path(organization, person)
      
      expect(page).to have_content('No Active Employment')
      expect(page).to have_content('must have an active employment')
    end

    it 'does not show required assignments section' do
      visit assignment_selection_organization_person_path(organization, person)
      
      expect(page).not_to have_content('Required for position')
    end
  end
end

