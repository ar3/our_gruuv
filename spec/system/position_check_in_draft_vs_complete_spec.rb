require 'rails_helper'

RSpec.describe 'Position Check-In Draft vs Complete Status', type: :system, critical: true do
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
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(manager_person).to receive(:can_manage_employment?).with(organization).and_return(true)
    allow(manager_person).to receive(:can_manage_employment?).and_return(true)
  end

  describe 'Manager saves as draft' do
    it 'should NOT mark the check-in as manager completed when saving as draft' do
      # Visit check-ins page as manager
      visit organization_person_check_ins_path(organization, employee_person)
      
      expect(page).to have_content('Check-Ins for John Doe')
      expect(page).to have_content('View Mode: Manager')
      expect(page).to have_content('Position: Software Engineer')

      # Fill in manager assessment but select "Save as Draft"
      within '.card.mb-4' do
        select '🔵 Praising/Trusting - Consistent strong performance', from: '_position_check_in_manager_rating'
        fill_in '_position_check_in_manager_private_notes', with: 'Manager draft notes'
        choose '_position_check_in_status_draft'  # This should NOT complete the check-in
      end
      
      click_button 'Save All Check-Ins'

      # Should show success message
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Check-in should still be in draft state (NOT completed)
      position_check_in = PositionCheckIn.find_by(teammate: employee_teammate)
      expect(position_check_in).to be_present
      
      puts "DEBUG: Manager completed_at: #{position_check_in.manager_completed_at}"
      puts "DEBUG: Manager completed_by: #{position_check_in.manager_completed_by}"
      puts "DEBUG: Status from form: #{find_field('_position_check_in_status_draft').checked?}"
      
      expect(position_check_in.manager_completed_at).to be_nil, "Manager should NOT be marked as completed when saving as draft"
      expect(position_check_in.manager_completed_by).to be_nil, "Manager should NOT be marked as completed by when saving as draft"
      
      # Status should show as "In Progress" not "Waiting for Employee"
      expect(page).to have_content('📝 In Progress')
      expect(page).not_to have_content('⏳ Waiting for Employee')
    end

    it 'should mark the check-in as manager completed when selecting "Mark Ready for Finalization"' do
      # Visit check-ins page as manager
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Fill in manager assessment and select "Mark Ready for Finalization"
      within '.card.mb-4' do
        select '🔵 Praising/Trusting - Consistent strong performance', from: '_position_check_in_manager_rating'
        fill_in '_position_check_in_manager_private_notes', with: 'Manager completed notes'
        choose '_position_check_in_status_complete'  # This SHOULD complete the check-in
      end
      
      click_button 'Save All Check-Ins'

      # Should show success message
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Check-in should be marked as manager completed
      position_check_in = PositionCheckIn.find_by(teammate: employee_teammate)
      expect(position_check_in).to be_present
      expect(position_check_in.manager_completed_at).to be_present, "Manager should be marked as completed when selecting 'Mark Ready for Finalization'"
      expect(position_check_in.manager_completed_by).to eq(manager_person), "Manager should be marked as completed by the current manager"
      
      # Status should show as "Waiting for Employee" not "In Progress"
      expect(page).to have_content('⏳ Waiting for Employee')
      expect(page).not_to have_content('📝 In Progress')
    end
  end

  describe 'Employee saves as draft' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
    end

    it 'should NOT mark the check-in as employee completed when saving as draft' do
      # Visit check-ins page as employee
      visit organization_person_check_ins_path(organization, employee_person)
      
      expect(page).to have_content('View Mode: Employee')

      # Fill in employee assessment but select "Save as Draft"
      within '.card.mb-4' do
        select '🟡 Actively Coaching - Mostly meeting expectations... Working on specific improvements', from: '_position_check_in_employee_rating'
        fill_in '_position_check_in_employee_private_notes', with: 'Employee draft notes'
        choose '_position_check_in_status_draft'  # This should NOT complete the check-in
      end
      
      click_button 'Save All Check-Ins'

      # Should show success message
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Check-in should still be in draft state (NOT completed)
      position_check_in = PositionCheckIn.find_by(teammate: employee_teammate)
      expect(position_check_in).to be_present
      expect(position_check_in.employee_completed_at).to be_nil, "Employee should NOT be marked as completed when saving as draft"
      
      # Status should show as "In Progress" not "Waiting for Manager"
      expect(page).to have_content('📝 In Progress')
      expect(page).not_to have_content('⏳ Waiting for Manager')
    end

    it 'should mark the check-in as employee completed when selecting "Mark Ready for Manager"' do
      # Visit check-ins page as employee
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Fill in employee assessment and select "Mark Ready for Manager"
      within '.card.mb-4' do
        select '🟡 Actively Coaching - Mostly meeting expectations... Working on specific improvements', from: '_position_check_in_employee_rating'
        fill_in '_position_check_in_employee_private_notes', with: 'Employee completed notes'
        choose '_position_check_in_status_complete'  # This SHOULD complete the check-in
      end
      
      click_button 'Save All Check-Ins'

      # Should show success message
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Check-in should be marked as employee completed
      position_check_in = PositionCheckIn.find_by(teammate: employee_teammate)
      expect(position_check_in).to be_present
      expect(position_check_in.employee_completed_at).to be_present, "Employee should be marked as completed when selecting 'Mark Ready for Manager'"
      
      # Status should show as "Waiting for Manager" not "In Progress"
      expect(page).to have_content('⏳ Waiting for Manager')
      expect(page).not_to have_content('📝 In Progress')
    end
  end
end
