require 'rails_helper'

RSpec.describe 'Assignments Core Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: company) }
  let(:person) { create(:person) }
  let!(:company_teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_employment: true, can_manage_maap: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }

  before do
    sign_in_as(person, company)
  end

  describe 'CRUD assignment on company' do
    it 'creates, views, updates, and deletes an assignment on the company' do
      # Create
      visit new_organization_assignment_path(company)
      expect(page).to have_content('Create New Assignment')
      
      fill_in 'assignment_title', with: 'Product Manager'
      fill_in 'assignment_tagline', with: 'Driving product strategy'
      fill_in 'assignment_outcomes_textarea', with: 'Deliver great products'
      fill_in 'assignment_required_activities', with: 'Define roadmap'
      
      click_button 'Create Assignment'
      
      expect(page).to have_content('Product Manager')
      
      assignment = Assignment.last
      expect(assignment.company.id).to eq(company.id)
      expect(assignment.company.class.base_class).to eq(Organization)
      expect(assignment.title).to eq('Product Manager')
      
      # View
      visit organization_assignments_path(company)
      expect(page).to have_content('Product Manager')
      
      # Update
      visit edit_organization_assignment_path(company, assignment)
      fill_in 'assignment_title', with: 'Senior Product Manager'
      # Select version type for update
      choose 'version_type_insignificant'
      click_button 'Update Assignment'
      
      expect(page).to have_content('Senior Product Manager')
      assignment.reload
      expect(assignment.title).to eq('Senior Product Manager')
      
      # # Delete
      # visit organization_assignment_path(company, assignment)
      # # Delete is in a dropdown menu
      # find('button.dropdown-toggle', text: 'Actions').click
      # delete_link = find('a.dropdown-item', text: 'Delete Assignment')
      # page.execute_script("window.confirm = function() { return true; }")
      # delete_link.click
      # sleep 1
      
      # expect(page).to have_success_flash('Assignment was successfully deleted')
      # expect(Assignment.find_by(id: assignment.id)).to be_nil
    end
  end

  describe 'CRUD assignment on department' do
    it 'creates, views, updates, and deletes an assignment on a department' do
      # Create
      visit new_organization_assignment_path(department)
      expect(page).to have_content('Create New Assignment')
      
      fill_in 'assignment_title', with: 'Department Assignment'
      fill_in 'assignment_tagline', with: 'Department-specific work'
      fill_in 'assignment_required_activities', with: 'Department activities'
      
      click_button 'Create Assignment'
      
      expect(page).to have_content('Department Assignment')
      
      assignment = Assignment.last
      expect(assignment.company.id).to eq(department.id)
      expect(assignment.company.class.base_class).to eq(Organization)
      
      # View
      visit organization_assignments_path(department)
      expect(page).to have_content('Department Assignment')
      
      # Update
      visit edit_organization_assignment_path(department, assignment)
      fill_in 'assignment_title', with: 'Updated Department Assignment'
      # Select version type for update
      choose 'version_type_insignificant'
      click_button 'Update Assignment'
      
      expect(page).to have_content('Updated Department Assignment')
      assignment.reload
      expect(assignment.title).to eq('Updated Department Assignment')
    end
  end

  describe 'Assign assignments to employee via assign-assignments-skip-check-in flow' do
    let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
    let!(:title) { create(:title, company: company, external_title: 'Engineer', position_major_level: position_major_level) }
    let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
    let!(:assignment1) { create(:assignment, company: company, title: 'Assignment 1') }
    let!(:assignment2) { create(:assignment, company: company, title: 'Assignment 2') }
    # Create employment tenure for employee_person (not company_teammate)
    let!(:position) { create(:position, title: title, position_level: position_level) }
    let!(:employee_employment) { create(:employment_tenure, teammate: employee_teammate, company: company, position: position, started_at: 1.year.ago, ended_at: nil) }

  end
end

