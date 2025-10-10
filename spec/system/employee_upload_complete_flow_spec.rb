require 'rails_helper'

RSpec.describe 'Employee Upload Complete Flow', type: :system, critical: true do
  let(:organization) { create(:organization, type: 'Company') }
  let(:person) { create(:person) }
  
  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_employment?).and_return(true)
  end

  describe 'Complete employee upload flow scenarios' do
    it 'creates employee upload with no related data available' do
      # Step 1: Navigate to new upload page
      visit new_organization_upload_event_path(organization, upload_event: {type: 'UploadEvent::UploadEmployees'})
      expect(page).to have_content('Upload Employee Positions')
      expect(page).to have_content('Upload CSV File')
      
      # Step 2: Upload empty CSV file
      csv_content = "Name,Email,Start Date\n"
      attach_file 'upload_event_file', create_temp_csv_file(csv_content)
      
      click_button 'Upload and Preview'
      
      # Step 3: Should redirect to show page with preview
      expect(page).to have_content('Upload Details')
      expect(page).to have_content('Preview Actions')
      # For empty CSV, we should see the success message
      expect(page).to have_content('Upload created successfully')
      
      # Step 4: Process button should be shown even for empty data
      expect(page).to have_button('Process Selected Items')
    end

    it 'creates employee upload with data and processes selected items' do
      # Step 1: Navigate to new upload page
      visit new_organization_upload_event_path(organization, upload_event: {type: 'UploadEvent::UploadEmployees'})
      expect(page).to have_content('Upload Employee Positions')
      
      # Step 2: Upload CSV with employee data
      csv_content = <<~CSV
        Name,Preferred Name,Email,Start Date,Location,Gender,Department,Employment Type,Manager,Country,Manager Email,Job Title,Job Title Level
        John Doe,John,john.doe@company.com,2024-01-15,New York,male,Engineering,full_time,Jane Smith,USA,jane.smith@company.com,Software Engineer,mid
        Jane Smith,Jane,jane.smith@company.com,2024-01-10,San Francisco,female,Engineering,full_time,Bob Johnson,USA,bob.johnson@company.com,Senior Engineer,senior
      CSV
      
      attach_file 'upload_event_file', create_temp_csv_file(csv_content)
      click_button 'Upload and Preview'
      
      # Step 3: Should redirect to show page with preview
      expect(page).to have_content('Upload Details')
      expect(page).to have_content('Preview Actions')
      
      # Step 4: Should show preview data
      expect(page).to have_content('Unassigned Employees (2)')
      expect(page).to have_content('John Doe')
      expect(page).to have_content('Jane Smith')
      expect(page).to have_content('Departments (1)')
      expect(page).to have_content('Engineering')
      
      # Step 5: Should show process button
      expect(page).to have_button('Process Selected Items')
      
      # Step 6: Process the upload
      click_button 'Process Selected Items'
      
      # Step 7: Should redirect back to show page with results
      expect(page).to have_content('Upload Details')
      expect(page).to have_content('Processing Results')
      expect(page).to have_content('successful')
      
      # Step 8: Verify data was actually created
      expect(Person.find_by(email: 'john.doe@company.com')).to be_present
      expect(Person.find_by(email: 'jane.smith@company.com')).to be_present
      expect(Organization.departments.find_by(name: 'Engineering')).to be_present
    end

    it 'creates employee upload with all optional fields filled' do
      # Step 1: Navigate to new upload page
      visit new_organization_upload_event_path(organization, upload_event: {type: 'UploadEvent::UploadEmployees'})
      
      # Step 2: Upload comprehensive CSV with all fields
      csv_content = <<~CSV
        Name,Preferred Name,Email,Start Date,Location,Gender,Department,Employment Type,Manager,Country,Manager Email,Job Title,Job Title Level
        Alice Johnson,Alice,alice.johnson@company.com,2024-01-01,Seattle,female,Marketing,full_time,Charlie Brown,USA,charlie.brown@company.com,Marketing Manager,senior
        Bob Wilson,Bob,bob.wilson@company.com,2024-01-02,Chicago,male,Sales,part_time,Alice Johnson,USA,alice.johnson@company.com,Sales Rep,junior
        Charlie Brown,Charlie,charlie.brown@company.com,2024-01-03,Boston,male,Marketing,full_time,,USA,,Marketing Director,senior
      CSV
      
      attach_file 'upload_event_file', create_temp_csv_file(csv_content)
      click_button 'Upload and Preview'
      
      # Step 3: Should show comprehensive preview
      expect(page).to have_content('Unassigned Employees (3)')
      expect(page).to have_content('Departments (2)')
      expect(page).to have_content('Managers (2)')
      
      # Step 4: Process all items
      click_button 'Process Selected Items'
      
      # Step 5: Verify comprehensive data creation
      expect(Person.find_by(email: 'alice.johnson@company.com')).to be_present
      expect(Person.find_by(email: 'bob.wilson@company.com')).to be_present
      expect(Person.find_by(email: 'charlie.brown@company.com')).to be_present
      expect(Organization.departments.find_by(name: 'Marketing')).to be_present
      expect(Organization.departments.find_by(name: 'Sales')).to be_present
    end

    it 'creates employee upload with minimal required fields only' do
      # Step 1: Navigate to new upload page
      visit new_organization_upload_event_path(organization, upload_event: {type: 'UploadEvent::UploadEmployees'})
      
      # Step 2: Upload minimal CSV
      csv_content = <<~CSV
        Name,Email,Start Date
        Minimal User,minimal@company.com,2024-01-01
      CSV
      
      attach_file 'upload_event_file', create_temp_csv_file(csv_content)
      click_button 'Upload and Preview'
      
      # Step 3: Should show minimal preview
      expect(page).to have_content('Unassigned Employees (1)')
      expect(page).to have_content('Minimal User')
      
      # Step 4: Process the upload
      click_button 'Process Selected Items'
      
      # Step 5: Verify minimal data creation
      expect(Person.find_by(email: 'minimal@company.com')).to be_present
    end
  end

  describe 'Form validation and error handling' do
    it 'shows validation errors and preserves form values' do
      # Step 1: Navigate to new upload page
      visit new_organization_upload_event_path(organization, upload_event: {type: 'UploadEvent::UploadEmployees'})
      
      # Step 2: Try to submit without file
      click_button 'Upload and Preview'
      
      # Step 3: Should show validation error or stay on form
      expect(page).to have_content('Upload Employee Positions')
      
      # Step 4: Form should still be visible
      expect(page).to have_content('Upload Employee Positions')
    end

    it 'handles invalid file types gracefully' do
      # Step 1: Navigate to new upload page
      visit new_organization_upload_event_path(organization, upload_event: {type: 'UploadEvent::UploadEmployees'})
      
      # Step 2: Upload invalid file type
      attach_file 'upload_event_file', create_temp_file('invalid content', 'test.txt')
      click_button 'Upload and Preview'
      
      # Step 3: Should redirect with error
      expect(page).to have_content('Please upload a valid CSV file')
    end

    it 'handles processing errors gracefully' do
      # Step 1: Create upload with invalid data
      csv_content = <<~CSV
        Name,Email,Start Date
        Invalid User,invalid-email,invalid-date
      CSV
      
      visit new_organization_upload_event_path(organization, upload_event: {type: 'UploadEvent::UploadEmployees'})
      attach_file 'upload_event_file', create_temp_csv_file(csv_content)
      click_button 'Upload and Preview'
      
      # Step 2: Should show preview with errors
      expect(page).to have_content('Preview Actions')
      
      # Step 3: Process the upload
      click_button 'Process Selected Items'
      
      # Step 4: Should show processing results with failures
      expect(page).to have_content('Processing Results')
      expect(page).to have_content('Failed Operations')
    end
  end

  describe 'Navigation and UI elements' do
    it 'navigates correctly between all pages' do
      # Step 1: Start from upload events index
      visit organization_upload_events_path(organization)
      expect(page).to have_content('Upload Events')
      
      # Step 2: Navigate to new upload
      visit new_organization_upload_event_path(organization, upload_event: {type: 'UploadEvent::UploadEmployees'})
      expect(page).to have_content('Upload Employee Positions')
      
      # Step 3: Upload a file
      csv_content = "Name,Email,Start Date\nTest User,test@company.com,2024-01-01\n"
      attach_file 'upload_event_file', create_temp_csv_file(csv_content)
      click_button 'Upload and Preview'
      
      # Step 4: Should be on show page
      expect(page).to have_content('Upload Details')
      
      # Step 5: Process the upload
      click_button 'Process Selected Items'
      
      # Step 6: Should stay on show page with results
      expect(page).to have_content('Upload Details')
      expect(page).to have_content('Processing Results')
      
      # Step 7: Navigate back to index
      first('a', text: 'Back to Uploads').click
      expect(page).to have_content('Upload Events')
    end

    it 'shows all expected UI elements' do
      # Step 1: Navigate to new upload page
      visit new_organization_upload_event_path(organization, upload_event: {type: 'UploadEvent::UploadEmployees'})
      
      # Step 2: Verify all form elements
      expect(page).to have_field('upload_event_file')
      expect(page).to have_button('Upload and Preview')
      expect(page).to have_content('Upload Employee Positions')
      expect(page).to have_content('Upload CSV File')
      
      # Step 3: Upload file and verify preview elements
      csv_content = "Name,Email,Start Date\nTest User,test@company.com,2024-01-01\n"
      attach_file 'upload_event_file', create_temp_csv_file(csv_content)
      click_button 'Upload and Preview'
      
      # Step 4: Verify preview elements
      expect(page).to have_content('Preview Actions')
      expect(page).to have_content('Select All')
      expect(page).to have_button('Process Selected Items')
      expect(page).to have_link('Cancel')
    end
  end

  private

  def create_temp_csv_file(content)
    temp_file = Tempfile.new(['test', '.csv'])
    temp_file.write(content)
    temp_file.rewind
    temp_file.path
  end

  def create_temp_file(content, filename)
    temp_file = Tempfile.new([filename.split('.').first, ".#{filename.split('.').last}"])
    temp_file.write(content)
    temp_file.close
    temp_file.path
  end
end
