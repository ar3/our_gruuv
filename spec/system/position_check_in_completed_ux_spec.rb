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
      
      within 'table' do
        select '🔵 Praising/Trusting - Consistent strong performance', from: '[position_check_in][manager_rating]'
        fill_in '[position_check_in][manager_private_notes]', with: 'John is doing excellent work on the frontend features'
        find('input[type="radio"][value="complete"]').click
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Step 2: Verify view-only mode is shown
      expect(page).to have_content('Ready for Finalization')
      expect(page).to have_content('🔵 Praising/Trusting')
      expect(page).to have_content('John is doing excellent work on the frontend features')
      expect(page).to have_content('John has not completed their assessment')
      
      # Should NOT show form fields
      expect(page).not_to have_select('[position_check_in][manager_rating]')
      expect(page).not_to have_field('[position_check_in][manager_private_notes]')
      
      # Should show radio buttons for status (check for any radio button with complete value)
      expect(page).to have_css('input[type="radio"][value="complete"]')
      expect(page).to have_css('input[type="radio"][value="draft"]')
      expect(page).to have_content('Ready for Finalization')
      expect(page).to have_content('Make Changes')
      
      # Step 3: Test undo functionality
      find('input[type="radio"][value="draft"]').click
      click_button 'Save All Check-Ins'
      
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Step 4: Verify back to edit mode
      expect(page).to have_content('Draft')
      expect(page).to have_select('[position_check_in][manager_rating]')
      expect(page).to have_field('[position_check_in][manager_private_notes]')
      
      # Values should be preserved
      expect(find_field('[position_check_in][manager_private_notes]').value).to eq('John is doing excellent work on the frontend features')
    end
  end

  describe 'Employee completed check-in UX' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
    end

    it 'shows view-only mode with undo option when employee has completed' do
      # Step 1: Complete employee assessment
      visit organization_person_check_ins_path(organization, employee_person)
      
      within 'table' do
        select '🟡 Actively Coaching - Mostly meeting expectations... Working on specific improvements', from: '[position_check_in][employee_rating]'
        fill_in '[position_check_in][employee_private_notes]', with: 'I feel I am meeting expectations but want to improve'
        find('input[type="radio"][value="complete"]').click
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Step 2: Verify view-only mode is shown
      expect(page).to have_content('Ready for Manager')
      expect(page).to have_content('🟡 Actively Coaching')
      expect(page).to have_content('I feel I am meeting expectations but want to improve')
      expect(page).to have_content('Waiting for Manager')
      
      # Should NOT show form fields
      expect(page).not_to have_select('[position_check_in][employee_rating]')
      expect(page).not_to have_field('[position_check_in][employee_private_notes]')
      
      # Should show radio buttons for status
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="complete"]:checked')
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="draft"]:not(:checked)')
      expect(page).to have_content('Ready for Manager')
      expect(page).to have_content('Make Changes')
      
      # Step 3: Test undo functionality
      find('input[type="radio"][value="draft"]').click
      click_button 'Save All Check-Ins'
      
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Step 4: Verify back to edit mode
      expect(page).to have_content('Draft')
      expect(page).to have_select('[position_check_in][employee_rating]')
      expect(page).to have_field('[position_check_in][employee_private_notes]')
      
      # Values should be preserved
      expect(find_field('[position_check_in][employee_private_notes]').value).to eq('I feel I am meeting expectations but want to improve')
    end
  end
end
