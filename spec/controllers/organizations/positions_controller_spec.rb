require 'rails_helper'

RSpec.describe Organizations::PositionsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }

  before do
    create(:teammate, person: person, organization: organization)
    sign_in_as_teammate(person, organization)
  end

  describe 'GET #index' do
    let!(:position_level_1) { create(:position_level, position_major_level: title.position_major_level, level: '1.1') }
    let!(:position_level_2) { create(:position_level, position_major_level: title.position_major_level, level: '1.2') }
    let!(:position_level_3) { create(:position_level, position_major_level: title.position_major_level, level: '1.3') }
    let!(:position_level_4) { create(:position_level, position_major_level: title.position_major_level, level: '2.1') }
    
    let!(:position_v1) { create(:position, title: title, position_level: position_level_1, semantic_version: '1.0.0') }
    let!(:position_v1_2) { create(:position, title: title, position_level: position_level_2, semantic_version: '1.2.3') }
    let!(:position_v2) { create(:position, title: title, position_level: position_level_3, semantic_version: '2.0.0') }
    let!(:position_v0) { create(:position, title: title, position_level: position_level_4, semantic_version: '0.1.0') }

    it 'returns all positions when no filters applied' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:positions)).to include(position_v1, position_v1_2, position_v2, position_v0)
    end

    it 'filters by major version 1' do
      get :index, params: { organization_id: organization.id, major_version: 1 }
      positions = assigns(:positions)
      expect(positions).to include(position_v1, position_v1_2)
      expect(positions).not_to include(position_v2, position_v0)
    end

    it 'filters by major version 2' do
      get :index, params: { organization_id: organization.id, major_version: 2 }
      positions = assigns(:positions)
      expect(positions).to include(position_v2)
      expect(positions).not_to include(position_v1, position_v1_2, position_v0)
    end

    it 'filters by major version 0' do
      get :index, params: { organization_id: organization.id, major_version: 0 }
      positions = assigns(:positions)
      expect(positions).to include(position_v0)
      expect(positions).not_to include(position_v1, position_v1_2, position_v2)
    end

    it 'returns empty result when filtering for non-existent major version' do
      get :index, params: { organization_id: organization.id, major_version: 99 }
      expect(assigns(:positions)).to be_empty
    end

    it 'combines major_version filter with title filter' do
      other_title = create(:title, company: organization)
      other_position_level = create(:position_level, position_major_level: other_title.position_major_level)
      other_position = create(:position, title: other_title, position_level: other_position_level, semantic_version: '1.0.0')

      get :index, params: { organization_id: organization.id, major_version: 1, title: title.id }
      positions = assigns(:positions)
      expect(positions).to include(position_v1, position_v1_2)
      expect(positions).not_to include(other_position, position_v2, position_v0)
    end

    it 'combines major_version filter with sorting' do
      get :index, params: { organization_id: organization.id, major_version: 1, sort: 'name' }
      positions = assigns(:positions)
      expect(positions).to include(position_v1, position_v1_2)
      expect(positions.length).to eq(2)
    end

    it 'sorts departments hierarchically by display_name' do
      position_major_level = create(:position_major_level)
      
      # Create departments with hierarchy
      dept_a = create(:department, company: organization, name: 'Department A')
      dept_a1 = create(:department, company: organization, parent_department: dept_a, name: 'Department A.1')
      dept_a2 = create(:department, company: organization, parent_department: dept_a, name: 'Department A.2')
      dept_b = create(:department, company: organization, name: 'Department B')
      dept_b1 = create(:department, company: organization, parent_department: dept_b, name: 'Department B.1')
      dept_c = create(:department, company: organization, name: 'Department C')
      
      # Create titles for each department with unique external titles
      title_a = create(:title, company: organization, department: dept_a, position_major_level: position_major_level, external_title: 'Title A')
      title_a1 = create(:title, company: organization, department: dept_a1, position_major_level: position_major_level, external_title: 'Title A1')
      title_a2 = create(:title, company: organization, department: dept_a2, position_major_level: position_major_level, external_title: 'Title A2')
      title_b = create(:title, company: organization, department: dept_b, position_major_level: position_major_level, external_title: 'Title B')
      title_b1 = create(:title, company: organization, department: dept_b1, position_major_level: position_major_level, external_title: 'Title B1')
      title_c = create(:title, company: organization, department: dept_c, position_major_level: position_major_level, external_title: 'Title C')
      title_no_dept = create(:title, company: organization, department: nil, position_major_level: position_major_level, external_title: 'Title No Dept')
      
      get :index, params: { organization_id: organization.id }
      
      titles_by_dept = assigns(:titles_by_department)
      dept_keys = titles_by_dept.keys
      
      # No department should come first
      expect(dept_keys.first).to be_nil
      
      # Then departments sorted hierarchically by display_name
      dept_names = dept_keys.compact.map(&:display_name)
      expect(dept_names).to eq([
        "Department A",
        "Department A > Department A.1",
        "Department A > Department A.2",
        "Department B",
        "Department B > Department B.1",
        "Department C"
      ])
    end

    it 'sorts titles alphanumerically within each department' do
      dept = create(:department, company: organization, name: 'Department A')
      position_major_level = create(:position_major_level)
      
      # Create titles with different names
      title_z = create(:title, company: organization, department: dept, external_title: 'Z Title', position_major_level: position_major_level)
      title_a = create(:title, company: organization, department: dept, external_title: 'A Title', position_major_level: position_major_level)
      title_m = create(:title, company: organization, department: dept, external_title: 'M Title', position_major_level: position_major_level)
      
      get :index, params: { organization_id: organization.id }
      
      titles_by_dept = assigns(:titles_by_department)
      # Find the department in the hash (it might be a different object instance)
      dept_key = titles_by_dept.keys.find { |k| k&.id == dept.id }
      
      expect(dept_key).not_to be_nil
      titles_in_dept = titles_by_dept[dept_key]
      expect(titles_in_dept.map(&:external_title)).to eq(['A Title', 'M Title', 'Z Title'])
    end
  end

  describe 'GET #show' do
    let(:position) { create(:position, title: title, position_level: position_level) }
    let(:manager_teammate) { CompanyTeammate.find_by(person: person, organization: organization) }
    let(:employee_person) { create(:person) }
    let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }

    context 'when current user is a manager' do
      before do
        # Make the manager have direct reports (any employee, not necessarily with this position)
        other_employee_person = create(:person)
        other_employee_teammate = create(:teammate, person: other_employee_person, organization: organization)
        other_position = create(:position, title: title, position_level: create(:position_level, position_major_level: title.position_major_level))
        create(:employment_tenure, 
          teammate: other_employee_teammate, 
          company: organization, 
          position: other_position,
          manager_teammate: manager_teammate,
          ended_at: nil
        )
        # Also create an employee with this specific position
        tenure = build(:employment_tenure, 
          teammate: employee_teammate, 
          company: organization, 
          manager_teammate: nil, # This employee doesn't need to be managed by the current user
          ended_at: nil
        )
        tenure.position = position
        tenure.save!
        # Verify manager has direct reports
        manager_teammate.reload
        expect(manager_teammate.has_direct_reports?).to be true
      end

      it 'loads employees with this position' do
        get :show, params: { organization_id: organization.id, id: position.id }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:employees_with_position)).to be_present
        expect(assigns(:employees_with_position).count).to eq(1)
        expect(assigns(:employees_with_position).first.teammate.id).to eq(employee_teammate.id)
      end

      it 'orders employees by last name, first name' do
        employee_person2 = create(:person, first_name: 'Alice', last_name: 'Zebra')
        employee_teammate2 = create(:teammate, person: employee_person2, organization: organization)
        tenure2 = build(:employment_tenure, 
          teammate: employee_teammate2, 
          company: organization, 
          manager_teammate: nil,
          ended_at: nil
        )
        tenure2.position = position
        tenure2.save!

        get :show, params: { organization_id: organization.id, id: position.id }
        
        employees = assigns(:employees_with_position)
        expect(employees.count).to eq(2)
        # Should be ordered by last name, so employee_person should come before employee_person2
        expect(employees.first.teammate.person.last_name).to be < employees.last.teammate.person.last_name
      end

      it 'only includes active employment tenures' do
        inactive_employee_person = create(:person)
        inactive_employee_teammate = create(:teammate, person: inactive_employee_person, organization: organization)
        inactive_tenure = build(:employment_tenure, 
          teammate: inactive_employee_teammate, 
          company: organization, 
          manager_teammate: nil,
          ended_at: 1.day.ago
        )
        inactive_tenure.position = position
        inactive_tenure.save!

        get :show, params: { organization_id: organization.id, id: position.id }
        
        employees = assigns(:employees_with_position)
        expect(employees.count).to eq(1)
        expect(employees.first.teammate.id).to eq(employee_teammate.id)
      end
    end

    context 'when current user is not a manager' do
      before do
        # Ensure manager has no direct reports
        manager_teammate.reload
        expect(manager_teammate.has_direct_reports?).to be false
        # Create an employee but don't make the current user their manager
        create(:employment_tenure, 
          teammate: employee_teammate, 
          company: organization, 
          position: position,
          manager_teammate: nil,
          ended_at: nil
        )
      end

      it 'does not load employees with this position' do
        get :show, params: { organization_id: organization.id, id: position.id }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:employees_with_position)).to be_nil
      end
    end
  end

  describe 'GET #manage_assignments' do
    let(:position) { create(:position, title: title, position_level: position_level) }
    let(:assignment) { create(:assignment, company: organization) }

    before do
      # Update existing teammate to have permission
      teammate = Teammate.find_by(person: person, organization: organization)
      teammate.update(can_manage_maap: true)
    end

    it 'loads assignments grouped by hierarchy' do
      assignment # Create the assignment
      get :manage_assignments, params: { organization_id: organization.id, id: position.id }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:assignments)).to be_present
      expect(assigns(:assignments_by_org)).to be_a(Hash)
      expect(response).to render_template(:manage_assignments)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'requires MAAP permission' do
      teammate = Teammate.find_by(person: person, organization: organization)
      teammate.update(can_manage_maap: false)
      
      get :manage_assignments, params: { organization_id: organization.id, id: position.id }
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end

    it 'allows access with MAAP permission even without employment management permission' do
      teammate = Teammate.find_by(person: person, organization: organization)
      teammate.update(can_manage_maap: true, can_manage_employment: false)
      
      get :manage_assignments, params: { organization_id: organization.id, id: position.id }
      
      expect(response).to have_http_status(:success)
    end

    it 'pre-populates existing position assignments' do
      assignment # Create the assignment
      existing_pa = create(:position_assignment, position: position, assignment: assignment, max_estimated_energy: 50)
      
      get :manage_assignments, params: { organization_id: organization.id, id: position.id }
      
      expect(assigns(:existing_position_assignments)).to be_present
      expect(assigns(:existing_position_assignments)[assignment.id]).to eq(existing_pa)
    end
  end

  describe 'PATCH #update_assignments' do
    let(:position) { create(:position, title: title, position_level: position_level) }
    let(:assignment) { create(:assignment, company: organization) }

    before do
      # Update existing teammate to have permission
      teammate = Teammate.find_by(person: person, organization: organization)
      teammate.update(can_manage_maap: true)
    end

    it 'creates new PositionAssignments when max_estimated_energy > 0' do
      assignment # Create the assignment
      patch :update_assignments, params: {
        organization_id: organization.id,
        id: position.id,
        position_assignments: {
          assignment.id.to_s => {
            min_estimated_energy: '20',
            max_estimated_energy: '40',
            assignment_type: 'required'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(organization, position))
      
      pa = PositionAssignment.find_by(position: position, assignment: assignment)
      expect(pa).to be_present
      expect(pa.max_estimated_energy).to eq(40)
    end

    it 'updates existing PositionAssignments' do
      assignment # Create the assignment
      existing_pa = create(:position_assignment, position: position, assignment: assignment, max_estimated_energy: 20)
      
      patch :update_assignments, params: {
        organization_id: organization.id,
        id: position.id,
        position_assignments: {
          assignment.id.to_s => {
            max_estimated_energy: '50',
            assignment_type: 'suggested'
          }
        }
      }
      
      existing_pa.reload
      expect(existing_pa.max_estimated_energy).to eq(50)
      expect(existing_pa.assignment_type).to eq('suggested')
    end

    it 'destroys PositionAssignments when max_estimated_energy is 0' do
      assignment # Create the assignment
      existing_pa = create(:position_assignment, position: position, assignment: assignment, max_estimated_energy: 30)
      
      patch :update_assignments, params: {
        organization_id: organization.id,
        id: position.id,
        position_assignments: {
          assignment.id.to_s => {
            max_estimated_energy: '0'
          }
        }
      }
      
      expect(PositionAssignment.find_by(id: existing_pa.id)).to be_nil
    end

    it 'destroys PositionAssignments not in params' do
      assignment # Create the assignment
      existing_pa = create(:position_assignment, position: position, assignment: assignment, max_estimated_energy: 30)
      other_assignment = create(:assignment, company: organization)
      
      patch :update_assignments, params: {
        organization_id: organization.id,
        id: position.id,
        position_assignments: {
          other_assignment.id.to_s => {
            max_estimated_energy: '50'
          }
        }
      }
      
      expect(PositionAssignment.find_by(id: existing_pa.id)).to be_nil
    end

    it 'requires update permission' do
      teammate = Teammate.find_by(person: person, organization: organization)
      teammate.update(can_manage_maap: false)
      
      patch :update_assignments, params: {
        organization_id: organization.id,
        id: position.id,
        position_assignments: {}
      }
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST #create' do
    let(:position_params) do
      {
        title_id: title.id,
        position_level_id: position_level.id,
        version_type: 'ready'
      }
    end

    context 'with can_manage_maap permission' do
      before do
        teammate = CompanyTeammate.find_by(person: person, organization: organization)
        teammate.update(can_manage_maap: true)
      end

      it 'creates a new position' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            position: position_params,
            title_id: title.id
          }
        }.to change(Position, :count).by(1)
        
        expect(response).to redirect_to(organization_position_path(organization, assigns(:position)))
        expect(flash[:notice]).to eq('Position was successfully created.')
      end
    end

    context 'without can_manage_maap permission' do
      before do
        teammate = CompanyTeammate.find_by(person: person, organization: organization)
        teammate.update(can_manage_maap: false)
      end

      it 'denies access' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            position: position_params,
            title_id: title.id
          }
        }.not_to change(Position, :count)
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'as admin' do
      let(:admin_person) { create(:person, :admin) }
      
      before do
        create(:teammate, person: admin_person, organization: organization, can_manage_maap: false)
        sign_in_as_teammate(admin_person, organization)
      end

      it 'allows creation even without can_manage_maap permission' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            position: position_params,
            title_id: title.id
          }
        }.to change(Position, :count).by(1)
        
        expect(response).to redirect_to(organization_position_path(organization, assigns(:position)))
      end
    end
  end

  describe 'PATCH #update' do
    let(:position) { create(:position, title: title, position_level: position_level) }
    let(:update_params) do
      {
        title_id: title.id,
        position_level_id: position_level.id,
        position_summary: 'Updated summary',
        version_type: 'insignificant'
      }
    end

    context 'with can_manage_maap permission' do
      before do
        teammate = CompanyTeammate.find_by(person: person, organization: organization)
        teammate.update(can_manage_maap: true)
      end

      it 'updates the position' do
        patch :update, params: {
          organization_id: organization.id,
          id: position.id,
          position: update_params
        }
        
        expect(response).to redirect_to(organization_position_path(organization, position))
        expect(flash[:notice]).to eq('Position was successfully updated.')
      end
    end

    context 'without can_manage_maap permission' do
      before do
        teammate = CompanyTeammate.find_by(person: person, organization: organization)
        teammate.update(can_manage_maap: false)
      end

      it 'denies access' do
        original_summary = position.position_summary
        
        patch :update, params: {
          organization_id: organization.id,
          id: position.id,
          position: update_params
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        position.reload
        expect(position.position_summary).to eq(original_summary)
      end
    end

    context 'as admin' do
      let(:admin_person) { create(:person, :admin) }
      
      before do
        create(:teammate, person: admin_person, organization: organization, can_manage_maap: false)
        sign_in_as_teammate(admin_person, organization)
      end

      it 'allows update even without can_manage_maap permission' do
        patch :update, params: {
          organization_id: organization.id,
          id: position.id,
          position: update_params
        }
        
        expect(response).to redirect_to(organization_position_path(organization, position))
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:position) { create(:position, title: title, position_level: position_level) }

    context 'with can_manage_maap permission' do
      before do
        teammate = CompanyTeammate.find_by(person: person, organization: organization)
        teammate.update(can_manage_maap: true)
      end

      it 'destroys the position' do
        expect {
          delete :destroy, params: {
            organization_id: organization.id,
            id: position.id
          }
        }.to change(Position, :count).by(-1)
        
        expect(response).to redirect_to(organization_positions_path(organization))
        expect(flash[:notice]).to eq('Position was successfully deleted.')
      end
    end

    context 'without can_manage_maap permission' do
      before do
        teammate = CompanyTeammate.find_by(person: person, organization: organization)
        teammate.update(can_manage_maap: false)
      end

      it 'denies access' do
        expect {
          delete :destroy, params: {
            organization_id: organization.id,
            id: position.id
          }
        }.not_to change(Position, :count)
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'as admin' do
      let(:admin_person) { create(:person, :admin) }
      
      before do
        create(:teammate, person: admin_person, organization: organization, can_manage_maap: false)
        sign_in_as_teammate(admin_person, organization)
      end

      it 'allows deletion even without can_manage_maap permission' do
        expect {
          delete :destroy, params: {
            organization_id: organization.id,
            id: position.id
          }
        }.to change(Position, :count).by(-1)
        
        expect(response).to redirect_to(organization_positions_path(organization))
      end
    end
  end
end

