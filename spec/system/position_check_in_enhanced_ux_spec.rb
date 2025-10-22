require 'rails_helper'

RSpec.describe 'Position Check-In Enhanced UX', type: :system, critical: true do
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

  describe 'Manager view scenarios' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
    end

    it 'shows form fields when manager has not completed' do
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Should show the form fields
      expect(page).to have_field('[position_check_in][manager_rating]')
      expect(page).to have_field('[position_check_in][manager_private_notes]')
      
      # Check for radio buttons using correct field names
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="draft"]')
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="complete"]')
    end

    it 'shows manager completed view with employee not ready when manager completed but employee has not' do
      # Manager completes their side
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      position_check_in.update!(
        manager_rating: 2,
        manager_private_notes: 'John is doing great work'
      )
      position_check_in.complete_manager_side!(completed_by: manager_person)

      visit organization_person_check_ins_path(organization, employee_person)
      
      # Should show manager's assessment in view-only mode
      expect(page).to have_content('Ready for Finalization')
      expect(page).to have_content('🔵 Praising/Trusting')
      expect(page).to have_content('John is doing great work')
      
      # Should show employee not ready status
      expect(page).to have_content('Waiting for Employee')
      
      # Should show radio buttons for making changes
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="complete"]:checked')
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="draft"]:not(:checked)')
      expect(page).to have_content('Make Changes')
    end

    it 'shows manager completed view with employee ready and finalization link when both completed' do
      # Both complete their sides
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      position_check_in.update!(
        manager_rating: 2,
        manager_private_notes: 'John is doing great work',
        employee_rating: 1,
        employee_private_notes: 'I feel I am meeting expectations'
      )
      position_check_in.complete_manager_side!(completed_by: manager_person)
      position_check_in.complete_employee_side!

      visit organization_person_check_ins_path(organization, employee_person)
      
      # Should show manager's assessment in view-only mode
      expect(page).to have_content('Both assessments are complete! Ready for finalization.')
      expect(page).to have_content('🔵 Praising/Trusting')
      expect(page).to have_content('John is doing great work')
      
      # Should show employee ready status with finalization link
      expect(page).to have_content('Both assessments are complete! Ready for finalization.')
      expect(page).to have_link('Go to Finalization')
    end
  end

  describe 'Employee view scenarios' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
    end

    it 'shows form fields when employee has not completed' do
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Should show the form fields
      expect(page).to have_field('[position_check_in][employee_rating]')
      expect(page).to have_field('[position_check_in][employee_private_notes]')
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="draft"]')
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="complete"]')
    end

    it 'shows employee completed view with manager not ready when employee completed but manager has not' do
      # Employee completes their side
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      position_check_in.update!(
        employee_rating: 1,
        employee_private_notes: 'I feel I am meeting expectations'
      )
      position_check_in.complete_employee_side!

      visit organization_person_check_ins_path(organization, employee_person)
      
      # Should show employee's assessment in view-only mode
      expect(page).to have_content('Ready for Manager')
      expect(page).to have_content('🟡 Actively Coaching')
      expect(page).to have_content('I feel I am meeting expectations')
      
      # Should show manager not ready status
      expect(page).to have_content('Waiting for Manager')
      
      # Should show radio buttons for making changes
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="complete"]:checked')
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="draft"]:not(:checked)')
      expect(page).to have_content('Make Changes')
    end

    it 'shows employee completed view with manager ready and finalization link when both completed' do
      # Both complete their sides
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      position_check_in.update!(
        manager_rating: 2,
        manager_private_notes: 'John is doing great work',
        employee_rating: 1,
        employee_private_notes: 'I feel I am meeting expectations'
      )
      position_check_in.complete_manager_side!(completed_by: manager_person)
      position_check_in.complete_employee_side!

      visit organization_person_check_ins_path(organization, employee_person)
      
      # Should show employee's assessment in view-only mode
      expect(page).to have_content('Both assessments are complete! Ready for finalization.')
      expect(page).to have_content('🟡 Actively Coaching')
      expect(page).to have_content('I feel I am meeting expectations')
      
      # Should show manager ready status with finalization link
      expect(page).to have_content('Both assessments are complete! Ready for finalization.')
      expect(page).to have_link('Go to Finalization')
    end
  end

  describe 'Make Changes functionality' do
    it 'allows manager to revert completed status back to draft' do
      # Manager completes their side
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      position_check_in.update!(
        manager_rating: 2,
        manager_private_notes: 'John is doing great work'
      )
      position_check_in.complete_manager_side!(completed_by: manager_person)

      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Should be in completed view
      expect(page).to have_content('Ready for Finalization')
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="complete"]:checked')
      
      # Click "Make Changes"
        find('input[type="radio"][value="draft"]').click
      click_button 'Save All Check-Ins'
      expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully.', visible: :all)
      
      # Should revert to form fields
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="draft"]:checked')
      
      # Verify database was updated
      position_check_in.reload
      expect(position_check_in.manager_completed_at).to be_nil
    end

    it 'allows employee to revert completed status back to draft' do
      # Employee completes their side
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      position_check_in.update!(
        employee_rating: 1,
        employee_private_notes: 'I feel I am meeting expectations'
      )
      position_check_in.complete_employee_side!

      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Should be in completed view
      expect(page).to have_content('Ready for Manager')
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="complete"]:checked')
      
      # Click "Make Changes"
        find('input[type="radio"][value="draft"]').click
      click_button 'Save All Check-Ins'
      expect(page).to have_css('.toast-body', text: 'Check-ins saved successfully.', visible: :all)
      
      # Should revert to form fields
      expect(page).to have_css('input[type="radio"][name="[position_check_in][status]"][value="draft"]:checked')
      
      # Verify database was updated
      position_check_in.reload
      expect(position_check_in.employee_completed_at).to be_nil
    end
  end
end
