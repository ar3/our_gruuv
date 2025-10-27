require 'rails_helper'

RSpec.describe 'Check-ins Field Alignment', type: :system do
  include_context 'check_in_test_data'
  
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:organization) { create(:organization, :company) }
  
  before do
    # Create teammate records
    create(:teammate, person: manager, organization: organization, can_manage_employment: true)
    create(:teammate, person: employee, organization: organization)
    
    # Set current organization
    manager.update!(current_organization: organization)
    employee.update!(current_organization: organization)
  end
  
  describe 'Rendered fields match controller expectations' do
    it 'position check-in fields match controller params' do
      # Create position check-in data
      position_type = create(:position_type, organization: organization)
      position_level = create(:position_level, position_major_level: position_type.position_major_level)
      position = create(:position, position_type: position_type, position_level: position_level)
      employment_tenure = create(:employment_tenure, teammate: employee.teammates.first, position: position, company: organization)
      create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
      
      sign_in_as(manager, organization)
      visit organization_person_check_ins_path(organization, employee, view: 'table')
      
      # Extract all form field names
      field_names = extract_form_field_names(page.html)
      
      # Verify position check-in fields have correct format
      position_fields = field_names.select { |name| name.include?('position_check_in') }
      
      # All position fields should start with check_ins[position_check_in]
      position_fields.each do |field|
        expect(field).to start_with('check_ins[position_check_in]'),
          "Field #{field} should start with 'check_ins[position_check_in]' to match controller expectations"
      end
      
      # Verify fields are within table structure
      expect(page).to have_css('select[name^="check_ins[position_check_in]"]')
      
      # Also verify within table context
      within('table', text: 'Position') do
        expect(page).to have_css('select[name^="check_ins[position_check_in]"]')
      end
    end
    
    it 'assignment check-in fields match controller params' do
      # Create assignment data
      assignment = create(:assignment, company: organization)
      create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment)
      
      sign_in_as(manager, organization)
      visit organization_person_check_ins_path(organization, employee, view: 'table')
      
      # Extract all form field names
      field_names = extract_form_field_names(page.html)
      
      # Verify assignment check-in fields have correct format
      assignment_fields = field_names.select { |name| name.include?('assignment_check_ins') }
      
      # All assignment fields should start with check_ins[assignment_check_ins]
      assignment_fields.each do |field|
        expect(field).to start_with('check_ins[assignment_check_ins]'),
          "Field #{field} should start with 'check_ins[assignment_check_ins]' to match controller expectations"
      end
      
      # Verify fields are within table structure
      within('table', text: 'ASSIGNMENTS') do
        expect(page).to have_css('select[name^="check_ins[assignment_check_ins]"]')
      end
    end
    
    it 'aspiration check-in fields match controller params' do
      # Create aspiration data
      aspiration = create(:aspiration, organization: organization)
      create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
      
      sign_in_as(manager, organization)
      visit organization_person_check_ins_path(organization, employee, view: 'table')
      
      # Extract all form field names
      field_names = extract_form_field_names(page.html)
      
      # Verify aspiration check-in fields have correct format
      aspiration_fields = field_names.select { |name| name.include?('aspiration_check_ins') }
      
      # All aspiration fields should start with check_ins[aspiration_check_ins]
      aspiration_fields.each do |field|
        expect(field).to start_with('check_ins[aspiration_check_ins]'),
          "Field #{field} should start with 'check_ins[aspiration_check_ins]' to match controller expectations"
      end
      
      # Verify fields are within table structure
      within('table', text: 'Aspiration') do
        expect(page).to have_css('select[name^="check_ins[aspiration_check_ins]"]')
      end
    end
    
    it 'verifies fields are within table rows (HTML structure)' do
      sign_in_as(manager, organization)
      visit organization_person_check_ins_path(organization, employee, view: 'table')
      
      # Parse HTML to verify fields are within <tr> elements
      doc = Nokogiri::HTML(page.html)
      
      # Find all form fields
      form_fields = doc.css('input[name], select[name], textarea[name]')
      
      # Check that fields are within table rows
      form_fields.each do |field|
        # Find the closest <tr> ancestor
        tr_ancestor = field.ancestors.find { |el| el.name == 'tr' }
        
        if field['name']&.include?('check_ins')
          expect(tr_ancestor).not_to be_nil,
            "Field #{field['name']} should be within a <tr> element for proper table structure"
        end
      end
    end
  end
  
  private
  
  def extract_form_field_names(html)
    doc = Nokogiri::HTML(html)
    doc.css('input[name], select[name], textarea[name]').map { |el| el['name'] }.compact.uniq.sort
  end
end
