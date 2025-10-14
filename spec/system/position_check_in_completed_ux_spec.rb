require 'rails_helper'

RSpec.describe 'Position Check-In Completed UX', type: :system, critical: true do
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

  describe 'Manager completed check-in UX' do
    it 'shows view-only mode with undo option when manager has completed' do
      # Step 1: Complete manager assessment
      visit organization_person_check_ins_path(organization, employee_person)
      
      within '.card.mb-4' do
        select '🔵 Praising/Trusting - Consistent strong performance', from: '_position_check_in_manager_rating'
        fill_in '_position_check_in_manager_private_notes', with: 'John is doing excellent work on the frontend features'
        choose '_position_check_in_status_complete'
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Step 2: Verify view-only mode is shown
      expect(page).to have_content('Your assessment is complete and ready for finalization')
      expect(page).to have_content('🔵 Praising/Trusting')
      expect(page).to have_content('John is doing excellent work on the frontend features')
      
      # Should NOT show form fields
      expect(page).not_to have_select('_position_check_in_manager_rating')
      expect(page).not_to have_field('_position_check_in_manager_private_notes')
      
      # Should show radio buttons for status
      expect(page).to have_checked_field('_position_check_in_status_complete')
      expect(page).to have_unchecked_field('_position_check_in_status_draft')
      expect(page).to have_content('Ready for Finalization')
      expect(page).to have_content('Make Changes')
      
      # Step 3: Test undo functionality
      choose '_position_check_in_status_draft'
      click_button 'Save All Check-Ins'
      
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Step 4: Verify back to edit mode
      expect(page).to have_content('📝 In Progress')
      expect(page).to have_select('_position_check_in_manager_rating')
      expect(page).to have_field('_position_check_in_manager_private_notes')
      
      # Values should be preserved
      expect(find_field('_position_check_in_manager_private_notes').value).to eq('John is doing excellent work on the frontend features')
    end
  end

  describe 'Employee completed check-in UX' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
    end

    it 'shows view-only mode with undo option when employee has completed' do
      # Step 1: Complete employee assessment
      visit organization_person_check_ins_path(organization, employee_person)
      
      within '.card.mb-4' do
        select '🟡 Actively Coaching - Mostly meeting expectations... Working on specific improvements', from: '_position_check_in_employee_rating'
        fill_in '_position_check_in_employee_private_notes', with: 'I feel I am meeting expectations but want to improve'
        choose '_position_check_in_status_complete'
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Step 2: Verify view-only mode is shown
      expect(page).to have_content('Your assessment is complete and ready for manager review')
      expect(page).to have_content('🟡 Actively Coaching')
      expect(page).to have_content('I feel I am meeting expectations but want to improve')
      
      # Should NOT show form fields
      expect(page).not_to have_select('_position_check_in_employee_rating')
      expect(page).not_to have_field('_position_check_in_employee_private_notes')
      
      # Should show radio buttons for status
      expect(page).to have_checked_field('_position_check_in_status_complete')
      expect(page).to have_unchecked_field('_position_check_in_status_draft')
      expect(page).to have_content('Ready for Manager')
      expect(page).to have_content('Make Changes')
      
      # Step 3: Test undo functionality
      choose '_position_check_in_status_draft'
      click_button 'Save All Check-Ins'
      
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Step 4: Verify back to edit mode
      expect(page).to have_content('📝 In Progress')
      expect(page).to have_select('_position_check_in_employee_rating')
      expect(page).to have_field('_position_check_in_employee_private_notes')
      
      # Values should be preserved
      expect(find_field('_position_check_in_employee_private_notes').value).to eq('I feel I am meeting expectations but want to improve')
    end
  end
end
