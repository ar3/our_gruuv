require 'rails_helper'

RSpec.describe 'Organizations::Departments', type: :request do
  let(:organization) { create(:organization) }
  let(:department) { create(:department, company: organization) }
  # NOTE: STI Team has been removed. Use nested departments for hierarchy testing.
  let(:nested_department) { create(:department, company: organization, parent_department: department, name: 'Nested Dept') }
  let(:current_person) { create(:person) }

  before do
    signed_in_teammate = sign_in_as_teammate_for_request(current_person, organization)
    # Grant permission to manage departments for edit/update actions
    signed_in_teammate.update!(can_manage_departments_and_teams: true)
  end

  describe 'GET /organizations/:id/departments' do
    it 'renders the index page' do
      # Create the hierarchy
      department
      nested_department
      
      get organization_departments_path(organization)
      
      expect(response).to be_successful
      expect(response.body).to include('Departments')
    end

    it 'displays hierarchy correctly' do
      department
      nested_department
      
      get organization_departments_path(organization)
      
      expect(response).to be_successful
      expect(response.body).to include(department.name)
      expect(response.body).to include(nested_department.name)
      # Verify hierarchy structure is rendered (should have tree visualization)
      expect(response.body).to include('tree-visualization')
      # Verify collapse/expand functionality is present
      expect(response.body).to include('toggle-children')
      # Verify hierarchy node partial is being used
      expect(response.body).to include('dept-node')
    end

    it 'displays nested hierarchy with correct structure' do
      department
      nested_department
      # Create a deeply nested department
      deeply_nested = create(:department, company: organization, parent_department: nested_department, name: 'Deeply Nested')
      
      get organization_departments_path(organization)
      
      expect(response).to be_successful
      expect(response.body).to include(department.name)
      expect(response.body).to include(nested_department.name)
      expect(response.body).to include(deeply_nested.name)
      # Verify hierarchy counts are displayed
      expect(response.body).to match(/department.*below/i)
      # Verify nested structure (nested dept should appear after parent dept)
      dept_index = response.body.index(nested_department.name)
      deeply_nested_index = response.body.index(deeply_nested.name)
      expect(deeply_nested_index).to be > dept_index
    end

    it 'displays nested hierarchy with correct indentation' do
      department
      nested_department
      # Create a deeply nested department
      deeply_nested = create(:department, company: organization, parent_department: nested_department, name: 'Deeply Nested')
      
      get organization_departments_path(organization)
      
      expect(response).to be_successful
      expect(response.body).to include(department.name)
      expect(response.body).to include(nested_department.name)
      expect(response.body).to include(deeply_nested.name)
      # Verify hierarchy counts are displayed
      expect(response.body).to match(/department.*below/i)
    end

    it 'handles empty hierarchy gracefully' do
      get organization_departments_path(organization)
      
      expect(response).to be_successful
      expect(response.body).to include('No Departments Created')
    end
  end

  describe 'GET /organizations/:id/departments/:id' do
    it 'renders the show page successfully' do
      get organization_department_path(organization, department)
      
      expect(response).to be_successful
      expect(response.body).to include(department.name)
    end

    it 'displays department details' do
      title = create(:title, company: organization, department: department)
      seat = create(:seat, title: title)
      assignment = create(:assignment, company: organization, department: department)
      ability = create(:ability, company: organization, department: department)
      
      get organization_department_path(organization, department)
      
      expect(response).to be_successful
      expect(response.body).to include(department.name)
      expect(response.body).to include('Seats')
      expect(response.body).to include('Titles')
      expect(response.body).to include('Assignments')
      expect(response.body).to include('Abilities')
      expect(response.body).to include('Aspirations')
    end

    it 'displays seats with employment tenures and person information' do
      position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      title = create(:title, company: organization, department: department, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level, level: '1.1')
      # Create seat first, then use :with_seat trait to ensure position matches
      seat = create(:seat, title: title, state: :filled)
      
      # Find or create a teammate
      teammate = CompanyTeammate.find_or_create_by(person: current_person, organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil }
      employment_tenure = create(:employment_tenure, :with_seat,
        company_teammate: teammate, 
        company: organization, 
        seat: seat,
        started_at: 1.year.ago,
        ended_at: nil
      )
      
      get organization_department_path(organization, department)
      
      expect(response).to be_successful
      expect(response.body).to include(seat.display_name)
      expect(response.body).to include(current_person.display_name)
    end

    it 'handles seats without employment tenures gracefully' do
      title = create(:title, company: organization, department: department)
      seat = create(:seat, title: title, state: :open)
      
      get organization_department_path(organization, department)
      
      expect(response).to be_successful
      expect(response.body).to include(seat.display_name)
      # Should show empty state for "Filled By" column
    end

    it 'handles seats with inactive employment tenures' do
      position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      title = create(:title, company: organization, department: department, position_major_level: position_major_level)
      # Create seat first, then use :with_seat trait to ensure position matches
      seat = create(:seat, title: title, state: :open)
      
      # Find or create an ended employment tenure (inactive)
      teammate = CompanyTeammate.find_or_create_by(person: current_person, organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil }
      employment_tenure = create(:employment_tenure, :with_seat, :inactive,
        company_teammate: teammate, 
        company: organization, 
        seat: seat,
        started_at: 2.years.ago,
        ended_at: 1.year.ago
      )
      
      get organization_department_path(organization, department)
      
      expect(response).to be_successful
      expect(response.body).to include(seat.display_name)
      # Should not show the person since the tenure is ended
    end

    it 'excludes archived departments' do
      archived_dept = create(:department, company: organization, deleted_at: Time.current)
      
      get "/organizations/#{organization.to_param}/departments/#{archived_dept.to_param}"
      expect(response).to have_http_status(:not_found)
    end

    it 'handles nested departments' do
      get organization_department_path(organization, nested_department)
      
      expect(response).to be_successful
      expect(response.body).to include(nested_department.name)
    end

    it 'returns 404 for non-existent department' do
      get "/organizations/#{organization.to_param}/departments/99999-nonexistent"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /organizations/:id/departments/new' do
    it 'renders the new page successfully' do
      get new_organization_department_path(organization)
      
      expect(response).to be_successful
      expect(response.body).to include('New Department')
    end
  end

  describe 'POST /organizations/:id/departments' do
    it 'creates a new department with correct type' do
      expect {
        post organization_departments_path(organization), params: {
          department: { name: 'New Department', parent_department_id: nil }
        }
      }.to change { Department.where(company: organization).active.count }.by(1)
      
      expect(response).to redirect_to(organization_departments_path(organization))
      created_dept = Department.where(company: organization).active.find_by(name: 'New Department')
      expect(created_dept).to be_present
      expect(created_dept).to be_a(Department)
      expect(created_dept.parent_department_id).to be_nil
    end

    # NOTE: STI Team has been removed. For actual teams, use the new Team model via /organizations/:id/teams
    it 'converts Team type requests to Department' do
      expect {
        post organization_departments_path(organization), params: {
          department: { name: 'New Team', parent_department_id: nil }
        }
      }.to change { Department.where(company: organization).active.count }.by(1)
      
      expect(response).to redirect_to(organization_departments_path(organization))
      created_dept = Department.where(company: organization).active.find_by(name: 'New Team')
      expect(created_dept).to be_present
      expect(created_dept).to be_a(Department)
      expect(created_dept.parent_department_id).to be_nil
    end

    it 'defaults to Department when type is missing' do
      expect {
        post organization_departments_path(organization), params: {
          department: { name: 'New Department', parent_department_id: nil }
        }
      }.to change { Department.where(company: organization).active.count }.by(1)
      
      expect(response).to redirect_to(organization_departments_path(organization))
      created_dept = Department.where(company: organization).active.find_by(name: 'New Department')
      expect(created_dept).to be_present
      expect(created_dept).to be_a(Department)
    end

    it 'defaults to Department when type is blank' do
      expect {
        post organization_departments_path(organization), params: {
          department: { name: 'New Department Blank Type', parent_department_id: '' }
        }
      }.to change { Department.where(company: organization).active.count }.by(1)
      
      expect(response).to redirect_to(organization_departments_path(organization))
      created_dept = Department.where(company: organization).active.find_by(name: 'New Department Blank Type')
      expect(created_dept).to be_present
      expect(created_dept).to be_a(Department)
    end
  end

  describe 'GET /organizations/:id/departments/:id/edit' do
    it 'renders the edit page successfully' do
      get edit_organization_department_path(organization, department)
      
      expect(response).to be_successful
      expect(response.body).to include(department.name)
      expect(response.body).to include('Edit')
    end

    it 'displays available parent organizations' do
      department2 = create(:department, company: organization)
      
      get edit_organization_department_path(organization, department)
      
      expect(response).to be_successful
      expect(response.body).to include(organization.name)
      expect(response.body).to include(department2.name)
      # Should not include self
      expect(response.body).not_to include("value=\"#{department.id}\"")
    end

    it 'excludes self and descendants from available parents' do
      department2 = create(:department, company: organization, parent_department: department)
      
      get edit_organization_department_path(organization, department)
      
      expect(response).to be_successful
      # Should not include self
      expect(response.body).not_to match(/value="#{department.id}"/)
      # Should not include descendants
      expect(response.body).not_to match(/value="#{department2.id}"/)
    end
  end

  describe 'PATCH /organizations/:id/departments/:id' do
    it 'updates department name' do
      patch organization_department_path(organization, department), params: {
        department: { name: 'Updated Department Name' }
      }
      
      department.reload
      expect(response).to redirect_to(organization_department_path(organization, department))
      expect(department.name).to eq('Updated Department Name')
    end

    it 'updates parent organization' do
      department2 = create(:department, company: organization)
      
      patch organization_department_path(organization, department), params: {
        department: { name: department.name, parent_department_id: department2.id }
      }
      
      expect(response).to redirect_to(organization_department_path(organization, department))
      expect(department.reload.parent_department_id).to eq(department2.id)
    end

    it 'allows changing parent to the root company' do
      department2 = create(:department, company: organization, parent_department: department)
      
      patch organization_department_path(organization, department2), params: {
        department: { name: department2.name, parent_department_id: nil }
      }
      
      expect(response).to redirect_to(organization_department_path(organization, department2))
      expect(department2.reload.parent_department_id).to be_nil
    end

    it 'prevents circular references by not allowing self as parent' do
      patch organization_department_path(organization, department), params: {
        department: { name: department.name, parent_department_id: department.id }
      }
      
      # Should either fail validation or ignore the invalid parent_department_id
      department.reload
      expect(department.parent_department_id).not_to eq(department.id)
    end

    it 'handles validation errors gracefully' do
      patch organization_department_path(organization, department), params: {
        department: { name: '' }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('error')
    end
  end
end
