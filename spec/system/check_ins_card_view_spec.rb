require 'rails_helper'
require_relative '../support/shared_examples/check_in_form_fields'

RSpec.describe 'Check-ins Card View', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person, full_name: 'Manager Person') }
  let(:employee) { create(:person, full_name: 'Employee Person') }
  let(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer') }
  let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level, level: '1.2') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:aspiration1) { create(:aspiration, organization: organization, name: 'Technical Skills') }
  let(:aspiration2) { create(:aspiration, organization: organization, name: 'Career Growth') }

  before do
    manager_teammate = create(:teammate, person: manager, organization: organization, can_manage_employment: true)
    employee_teammate = create(:teammate, person: employee, organization: organization)
    employment_tenure = create(:employment_tenure, teammate: employee_teammate, company: organization, manager: manager, position: position)

    # Create position check-in
    create(:position_check_in, teammate: employee_teammate, employment_tenure: employment_tenure).update!(
      employee_rating: 'working_to_meet',
      manager_rating: 'working_to_meet',
      employee_private_notes: 'Making good progress',
      manager_private_notes: 'Outstanding performance'
    )

    # Create assignment check-ins
    assignment1 = create(:assignment, company: organization, title: 'Frontend Development')
    assignment2 = create(:assignment, company: organization, title: 'Backend Development')

    # Create assignment tenures (required for assignment check-ins to be loaded)
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1)
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment2)

    create(:assignment_check_in, teammate: employee_teammate, assignment: assignment1).update!(
      employee_rating: 'meeting',
      manager_rating: 'meeting',
      employee_private_notes: 'Good progress on frontend',
      manager_private_notes: 'Solid frontend work'
    )

    create(:assignment_check_in, teammate: employee_teammate, assignment: assignment2).update!(
      employee_rating: 'exceeding',
      manager_rating: 'exceeding',
      employee_private_notes: 'Excelling at backend',
      manager_private_notes: 'Outstanding backend skills'
    )

    # Create aspiration check-ins
    create(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration1).update!(
      employee_rating: 'exceeding',
      manager_rating: 'exceeding',
      employee_private_notes: 'Mastering new technologies',
      manager_private_notes: 'Excellent technical growth'
    )
    create(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration2).update!(
      employee_rating: 'meeting',
      manager_rating: 'meeting',
      employee_private_notes: 'Growing in career',
      manager_private_notes: 'Good career development'
    )
  end

  describe 'Manager View Form Fields' do
    let(:user) { manager }
    
    include_examples "position check-in form fields", "card"
    include_examples "assignment check-in form fields", "card"
    include_examples "aspiration check-in form fields", "card"
  end

  describe 'Employee View Form Fields' do
    let(:user) { employee }
    
    include_examples "employee check-in form fields", "card"
  end

  describe 'Card View Mode' do
    it 'shows card view when requested' do
      sign_in_as(manager, organization)
      visit organization_person_check_ins_path(organization, employee, view: 'card')

      # Should see individual form cards
      expect(page).to have_css('.card', text: 'Position:')
      expect(page).to have_css('.card', text: 'Assignment:')
      expect(page).to have_css('.card', text: 'Aspiration:')
    end

    it 'allows form submission in card view' do
      sign_in_as(manager, organization)
      visit organization_person_check_ins_path(organization, employee, view: 'card')

      # Should have the same save button as table view
      expect(page).to have_button('Save All Check-Ins')

      # Should be able to fill out forms and submit
      select '🔵 Praising/Trusting', from: '[position_check_in][manager_rating]'
      fill_in '[position_check_in][manager_private_notes]', with: 'Great work in card view!'

      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
    end
  end
end
