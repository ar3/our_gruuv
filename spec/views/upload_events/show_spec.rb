require 'rails_helper'

# Temporary helper module for the view spec
module TestUploadEventsHelper
  def current_organization
    @current_organization ||= Organization.first
  end
  
  def current_person
    @current_person ||= Person.first
  end
end

RSpec.describe 'upload_events/show', type: :view do
  include TestUploadEventsHelper
  
  let(:organization) { create(:organization, type: 'Company') }
  let(:person) { create(:person) }
  let(:upload_event) { create(:upload_employees, organization: organization, creator: person, initiator: person) }

  before do
    assign(:upload_event, upload_event)
    @current_organization = organization
    @current_person = person
  end

  describe 'preview actions display' do
    context 'with employee preview data' do
      before do
        upload_event.update!(
          status: 'preview',
          preview_actions: {
            'unassigned_employees' => [
              { 'row' => 1, 'name' => 'John Doe', 'email' => 'john@example.com', 'will_create' => true },
              { 'row' => 2, 'name' => 'Jane Smith', 'email' => 'jane@example.com', 'will_create' => false, 'existing_id' => 123, 'existing_name' => 'Jane Smith' }
            ],
            'departments' => [
              { 'row' => 1, 'name' => 'Engineering', 'will_create' => true },
              { 'row' => 2, 'name' => 'Marketing', 'will_create' => false, 'existing_id' => 456 }
            ],
            'managers' => [
              { 'row' => 1, 'name' => 'Bob Johnson', 'email' => 'bob@example.com', 'will_create' => true }
            ],
            'position_types' => [
              { 'row' => 1, 'external_title' => 'Software Engineer', 'will_create' => true }
            ],
            'positions' => [
              { 'row' => 1, 'position_type_title' => 'Software Engineer', 'position_level' => 'mid', 'will_create' => true }
            ],
            'teammates' => [
              { 'row' => 1, 'person_name' => 'John Doe', 'person_email' => 'john@example.com', 'organization_name' => 'Company', 'type' => 'CompanyTeammate', 'first_employed_at' => '2024-01-15', 'will_create' => true }
            ],
            'employment_tenures' => [
              { 'row' => 1, 'person_name' => 'John Doe', 'person_email' => 'john@example.com', 'position_title' => 'Software Engineer', 'manager_name' => 'Bob Johnson', 'started_at' => '2024-01-15', 'will_create' => true }
            ]
          }
        )
      end

      it 'renders unassigned employees section' do
        render
        
        expect(rendered).to have_content('Unassigned Employees (2)')
        expect(rendered).to have_content('John Doe')
        expect(rendered).to have_content('jane@example.com')
        expect(rendered).to have_content('New')
        expect(rendered).to have_content('Update')
        expect(rendered).to have_css('input[type="checkbox"][name="selected_unassigned_employees[]"][value="1"]')
        expect(rendered).to have_css('input[type="checkbox"][name="selected_unassigned_employees[]"][value="2"]')
      end

      it 'renders departments section' do
        render
        
        expect(rendered).to have_content('Departments (2)')
        expect(rendered).to have_content('Engineering')
        expect(rendered).to have_content('Marketing')
        expect(rendered).to have_css('input[type="checkbox"][name="selected_departments[]"][value="1"]')
        expect(rendered).to have_css('input[type="checkbox"][name="selected_departments[]"][value="2"]')
      end

      it 'renders managers section' do
        render
        
        expect(rendered).to have_content('Managers (1)')
        expect(rendered).to have_content('Bob Johnson')
        expect(rendered).to have_content('bob@example.com')
        expect(rendered).to have_css('input[type="checkbox"][name="selected_managers[]"][value="1"]')
      end

      it 'renders position types section' do
        render
        
        expect(rendered).to have_content('Position Types (1)')
        expect(rendered).to have_content('Software Engineer')
        expect(rendered).to have_css('input[type="checkbox"][name="selected_position_types[]"][value="1"]')
      end

      it 'renders positions section' do
        render
        
        expect(rendered).to have_content('Positions (1)')
        expect(rendered).to have_content('Software Engineer')
        expect(rendered).to have_content('mid')
        expect(rendered).to have_css('input[type="checkbox"][name="selected_positions[]"][value="1"]')
      end

      it 'renders teammates section' do
        render
        
        expect(rendered).to have_content('Teammates (1)')
        expect(rendered).to have_content('John Doe')
        expect(rendered).to have_content('jane@example.com')
        expect(rendered).to have_content('Company')
        expect(rendered).to have_content('CompanyTeammate')
        expect(rendered).to have_css('input[type="checkbox"][name="selected_teammates[]"][value="1"]')
      end

      it 'renders employment tenures section' do
        render
        
        expect(rendered).to have_content('Employment Tenures (1)')
        expect(rendered).to have_content('John Doe')
        expect(rendered).to have_content('jane@example.com')
        expect(rendered).to have_content('Software Engineer')
        expect(rendered).to have_content('Bob Johnson')
        expect(rendered).to have_css('input[type="checkbox"][name="selected_employment_tenures[]"][value="1"]')
      end

      it 'renders process form with correct action' do
        render
        
        expect(rendered).to have_css("form[action='#{process_upload_organization_upload_event_path(organization, upload_event)}'][method='post']")
        expect(rendered).to have_button('Process Selected Items')
        expect(rendered).to have_link('Cancel', href: organization_upload_events_path(organization))
      end

      it 'renders select all checkboxes' do
        render
        
        expect(rendered).to have_css('input[type="checkbox"][data-target="unassigned-employees-checkbox"]')
        expect(rendered).to have_css('input[type="checkbox"][data-target="departments-checkbox"]')
        expect(rendered).to have_css('input[type="checkbox"][data-target="managers-checkbox"]')
        expect(rendered).to have_css('input[type="checkbox"][data-target="position-types-checkbox"]')
        expect(rendered).to have_css('input[type="checkbox"][data-target="positions-checkbox"]')
        expect(rendered).to have_css('input[type="checkbox"][data-target="teammates-checkbox"]')
        expect(rendered).to have_css('input[type="checkbox"][data-target="employment-tenures-checkbox"]')
      end
    end

    context 'with empty preview data' do
      before do
        upload_event.update!(
          status: 'preview',
          preview_actions: {}
        )
      end

      it 'shows no data available message' do
        render
        
        expect(rendered).to have_content('No data available')
        expect(rendered).to have_content('This upload event doesn\'t have any preview actions or results to display')
        expect(rendered).not_to have_button('Process Selected Items')
      end
    end

    context 'when not in preview status' do
      before do
        upload_event.update!(status: 'completed')
      end

      it 'does not render preview actions section' do
        render
        
        expect(rendered).not_to have_content('Preview Actions')
        expect(rendered).not_to have_button('Process Selected Items')
      end
    end
  end

  describe 'processing results display' do
    context 'with successful results' do
      before do
        upload_event.update!(
          status: 'completed',
          results: {
            'successes' => [
              { 'type' => 'unassigned_employee', 'action' => 'created', 'name' => 'John Doe', 'row' => 1 },
              { 'type' => 'department', 'action' => 'created', 'name' => 'Engineering', 'row' => 1 },
              { 'type' => 'employment_tenure', 'action' => 'created', 'person_name' => 'John Doe', 'position_title' => 'Software Engineer', 'row' => 1 }
            ],
            'failures' => []
          }
        )
      end

      it 'renders successful operations section' do
        render
        
        expect(rendered).to have_content('Processing Results')
        expect(rendered).to have_content('Successful Operations (3)')
        expect(rendered).to have_content('John Doe')
        expect(rendered).to have_content('Engineering')
        expect(rendered).to have_content('Software Engineer')
        expect(rendered).to have_css('.table-success')
      end

      it 'does not render failed operations section when no failures' do
        render
        
        expect(rendered).not_to have_content('Failed Operations')
        expect(rendered).not_to have_css('.table-danger')
      end
    end

    context 'with failed results' do
      before do
        upload_event.update!(
          status: 'completed',
          results: {
            'successes' => [
              { 'type' => 'unassigned_employee', 'action' => 'created', 'name' => 'John Doe', 'row' => 1 }
            ],
            'failures' => [
              { 'type' => 'unassigned_employee', 'error' => 'Invalid email format', 'data' => { 'email' => 'invalid-email' }, 'row' => 2 },
              { 'type' => 'employment_tenure', 'error' => 'Missing position', 'data' => { 'person_name' => 'Jane Smith' }, 'row' => 2 }
            ]
          }
        )
      end

      it 'renders both successful and failed operations' do
        render
        
        expect(rendered).to have_content('Successful Operations (1)')
        expect(rendered).to have_content('Failed Operations (2)')
        expect(rendered).to have_content('Invalid email format')
        expect(rendered).to have_content('Missing position')
        expect(rendered).to have_css('.table-success')
        expect(rendered).to have_css('.table-danger')
      end
    end

    context 'with processing status' do
      before do
        upload_event.update!(status: 'processing')
      end

      it 'renders processing indicator' do
        render
        
        expect(rendered).to have_content('Processing')
        expect(rendered).to have_content('Processing upload... This may take a few minutes')
        expect(rendered).to have_css('.spinner-border')
        expect(rendered).to have_content('You can refresh this page to check the status')
      end
    end

    context 'with failed status' do
      before do
        upload_event.update!(
          status: 'failed',
          results: {
            'error' => 'CSV parsing failed: Invalid format',
            'failures' => [
              { 'type' => 'system_error', 'error' => 'Database connection timeout', 'data' => {}, 'row' => 1 }
            ]
          }
        )
      end

      it 'renders failure message and details' do
        render
        
        expect(rendered).to have_content('Processing Failed')
        expect(rendered).to have_content('CSV parsing failed: Invalid format')
        expect(rendered).to have_css('.alert-danger')
        expect(rendered).to have_content('Failed Operations (1)')
        expect(rendered).to have_content('Database connection timeout')
      end
    end
  end

  describe 'upload information display' do
    before do
      upload_event.update!(
        filename: 'employees.csv',
        created_at: Time.parse('2024-01-15 10:30:00'),
        attempted_at: Time.parse('2024-01-15 10:35:00')
      )
    end

    it 'renders upload details' do
      render
      
      expect(rendered).to have_content('Upload Details')
      expect(rendered).to have_content('employees.csv')
      expect(rendered).to have_content('January 15, 2024 at 10:30 AM')
      expect(rendered).to have_content(person.display_name)
    end

    it 'renders status badge with correct color' do
      upload_event.update!(status: 'completed')
      render
      
      expect(rendered).to have_css('.badge.bg-success', text: 'Completed')
    end

    it 'renders attempted time when available' do
      render
      
      expect(rendered).to have_content('January 15, 2024 at 10:35 AM')
    end

    it 'renders success/failure counts for completed uploads' do
      upload_event.update!(
        status: 'completed',
        results: {
          'successes' => [{ 'type' => 'person' }],
          'failures' => [{ 'type' => 'person' }]
        }
      )
      render
      
      expect(rendered).to have_content('1 successful')
      expect(rendered).to have_content('1 failed')
    end
  end

  describe 'navigation elements' do
    it 'renders back navigation link' do
      render
      
      expect(rendered).to have_link('Back to Uploads', href: organization_upload_events_path(organization))
      expect(rendered).to have_css('i.bi.bi-arrow-left')
    end

    it 'renders delete button when upload can be destroyed' do
      upload_event.update!(status: 'preview')
      render
      
      expect(rendered).to have_link('Delete', href: organization_upload_event_path(organization, upload_event))
    end

    it 'does not render delete button when upload cannot be destroyed' do
      upload_event.update!(status: 'completed')
      render
      
      expect(rendered).not_to have_link('Delete')
    end
  end

  describe 'JavaScript functionality' do
    it 'includes checkbox selection JavaScript' do
      render
      
      expect(rendered).to have_content('document.addEventListener(\'DOMContentLoaded\'')
      expect(rendered).to have_content('Handle "Select All" checkboxes')
      expect(rendered).to have_content('selectAll.addEventListener(\'change\'')
    end
  end
end
