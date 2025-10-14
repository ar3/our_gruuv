require 'rails_helper'

RSpec.describe 'Position Check-In Ready for Finalization UX', type: :system, critical: true do
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

  describe 'Ready for Finalization state' do
    it 'shows "Go to Finalization" button when both sides are complete' do
      # Complete both employee and manager assessments
      position_check_in = PositionCheckIn.find_or_create_open_for(employee_teammate)
      position_check_in.update!(
        employee_rating: 1,
        employee_private_notes: 'I feel I am meeting expectations',
        manager_rating: 2,
        manager_private_notes: 'John is doing great work'
      )
      position_check_in.complete_employee_side!
      position_check_in.complete_manager_side!(completed_by: manager_person)

      # Test manager view
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      visit organization_person_check_ins_path(organization, employee_person)
      
      expect(page).to have_content('Both assessments are complete! Ready for finalization.')
      expect(page).to have_content('Your Assessment')
      expect(page).to have_content('Other Person\'s Assessment')
      expect(page).to have_content('🔵 Praising/Trusting') # Manager's rating
      expect(page).to have_content('🟡 Actively Coaching') # Employee's rating
      
      # Should have "Go to Finalization" button
      expect(page).to have_link('Go to Finalization', href: organization_person_finalization_path(organization, employee_person))
      
      # Test employee view
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
      visit organization_person_check_ins_path(organization, employee_person)
      
      expect(page).to have_content('Both assessments are complete! Ready for finalization.')
      expect(page).to have_content('Your Assessment')
      expect(page).to have_content('Other Person\'s Assessment')
      expect(page).to have_content('🟡 Actively Coaching') # Employee's rating
      expect(page).to have_content('🔵 Praising/Trusting') # Manager's rating
      
      # Should have "Go to Finalization" button
      expect(page).to have_link('Go to Finalization', href: organization_person_finalization_path(organization, employee_person))
    end
  end

  describe 'Finalization page for employees' do
    it 'shows read-only view for employees on finalization page' do
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

      # Visit finalization page as employee
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
      visit organization_person_finalization_path(organization, employee_person)
      
      expect(page).to have_content('Review your check-ins that are ready for finalization')
      expect(page).to have_content('Position Check-In - Ready for Finalization')
      expect(page).to have_content('Your manager will review and finalize this check-in')
      
      # Should show both assessments
      expect(page).to have_content('Your Assessment')
      expect(page).to have_content('Manager\'s Assessment')
      expect(page).to have_content('🟡 Actively Coaching') # Employee's rating
      expect(page).to have_content('🔵 Praising/Trusting') # Manager's rating
      
      # Should NOT have form fields or submit buttons
      expect(page).not_to have_select('position_official_rating')
      expect(page).not_to have_field('position_shared_notes')
      expect(page).not_to have_button('Finalize Selected Check-Ins')
      
      # Should have informational message
      expect(page).to have_content('Your manager will review both assessments and set the official rating.')
    end
  end

  describe 'Finalization page for managers' do
    it 'shows editable form for managers on finalization page' do
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

      # Visit finalization page as manager
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
      visit organization_person_finalization_path(organization, employee_person)
      
      expect(page).to have_content('Review ready check-ins and finalize selected ones')
      
      # Should have form fields
      expect(page).to have_select('position_official_rating')
      expect(page).to have_field('position_shared_notes')
      expect(page).to have_button('Finalize Selected Check-Ins')
      
      # Should show both assessments
      expect(page).to have_content('Employee Perspective')
      expect(page).to have_content('Manager Perspective')
      expect(page).to have_content('🟡 Actively Coaching') # Employee's rating
      expect(page).to have_content('🔵 Praising/Trusting') # Manager's rating
    end
  end
end
