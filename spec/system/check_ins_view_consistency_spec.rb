require 'rails_helper'

RSpec.describe 'Check-ins View Consistency', type: :system do
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

  describe 'Manager View Consistency' do
    it 'ensures card and table views have identical form fields' do
      sign_in_as(manager, organization)
      
      # Visit both views
      visit organization_person_check_ins_path(organization, employee, view: 'card')
      card_page_html = page.html
      
      visit organization_person_check_ins_path(organization, employee, view: 'table')
      table_page_html = page.html
      
      # Extract form field names from both pages
      card_field_names = extract_form_field_names(card_page_html)
      table_field_names = extract_form_field_names(table_page_html)
      
      # Ensure they're identical
      expect(card_field_names).to match_array(table_field_names), 
        "Form field names differ between card and table views:\nCard: #{card_field_names}\nTable: #{table_field_names}"
    end

    it 'ensures both views submit identical form data' do
      sign_in_as(manager, organization)
      
      # Fill out card view
      visit organization_person_check_ins_path(organization, employee, view: 'card')
      fill_card_form_with_test_data
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Get the saved data
      position_check_in = PositionCheckIn.last
      card_result = {
        position_manager_rating: position_check_in.manager_rating,
        position_manager_notes: position_check_in.manager_private_notes
      }
      
      # Fill out table view with same data
      visit organization_person_check_ins_path(organization, employee, view: 'table')
      fill_table_form_with_test_data
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully')
      
      # Get the saved data
      position_check_in.reload
      table_result = {
        position_manager_rating: position_check_in.manager_rating,
        position_manager_notes: position_check_in.manager_private_notes
      }
      
      # Ensure identical results
      expect(card_result).to eq(table_result), 
        "Form submission results differ between card and table views:\nCard: #{card_result}\nTable: #{table_result}"
    end
  end

  describe 'Employee View Consistency' do
    it 'ensures card and table views have identical form fields for employees' do
      sign_in_as(employee, organization)
      
      # Visit both views
      visit organization_person_check_ins_path(organization, employee, view: 'card')
      card_page_html = page.html
      
      visit organization_person_check_ins_path(organization, employee, view: 'table')
      table_page_html = page.html
      
      # Extract form field names from both pages
      card_field_names = extract_form_field_names(card_page_html)
      table_field_names = extract_form_field_names(table_page_html)
      
      # Ensure they're identical
      expect(card_field_names).to match_array(table_field_names), 
        "Form field names differ between card and table views for employee:\nCard: #{card_field_names}\nTable: #{table_field_names}"
    end
  end

  private

  def extract_form_field_names(html)
    # Parse HTML and extract all form field names
    doc = Nokogiri::HTML(html)
    doc.css('input[name], select[name], textarea[name]').map { |el| el['name'] }.compact.uniq.sort
  end

  def fill_card_form_with_test_data
    # Fill position
    select '🔵 Praising/Trusting', from: '[position_check_in][manager_rating]'
    fill_in '[position_check_in][manager_private_notes]', with: 'Test card data - great work!'
    
    # Mark as complete - find by value instead of ID
    find('input[name="[position_check_in][status]"][value="complete"]').click
  end

  def fill_table_form_with_test_data
    # Fill position in table view
    within('table', match: :first) do
      manager_rating_select = find('select[name*="position_check_in"][name*="manager_rating"]')
      manager_rating_select.select('🔵 Praising/Trusting')
      
      manager_notes_textarea = find('textarea[name*="position_check_in"][name*="manager_private_notes"]')
      manager_notes_textarea.fill_in(with: 'Test table data - great work!')
      
      # Mark as complete
      find('input[name*="position_check_in"][name*="status"][value="complete"]').click
    end
  end
end
