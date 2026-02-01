require 'rails_helper'

RSpec.describe Organizations::DepartmentsController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: organization) }
  # NOTE: STI Team has been removed. Use nested departments for hierarchy testing.
  let(:nested_department) { create(:organization, :department, parent: department, name: 'Nested Dept') }
  let(:current_person) { create(:person, og_admin: false) }
  let(:teammate) do
    existing = Teammate.find_by(person: current_person, organization: organization)
    existing || create(:teammate, person: current_person, organization: organization)
  end

  before do
    teammate # Ensure teammate exists
    sign_in_as_teammate(current_person, organization)
    allow(controller).to receive(:set_organization).and_return(true)
    controller.instance_variable_set(:@organization, organization)
  end

  describe 'GET #index' do
    it 'loads active descendants with proper includes' do
      # Create the hierarchy
      department
      nested_department
      
      get :index, params: { organization_id: organization.id }
      
      expect(response).to be_successful
      expect(assigns(:departments)).to be_present
      expect(assigns(:hierarchy_tree)).to be_present
    end

    it 'excludes archived organizations' do
      archived_dept = create(:organization, :department, parent: organization, deleted_at: Time.current)
      department
      nested_department
      
      get :index, params: { organization_id: organization.id }
      
      expect(assigns(:departments).map(&:id)).to include(department.id)
      expect(assigns(:departments).map(&:id)).not_to include(archived_dept.id)
    end

    it 'handles empty descendants gracefully' do
      get :index, params: { organization_id: organization.id }
      
      expect(response).to be_successful
      expect(assigns(:departments)).to be_empty
      expect(assigns(:hierarchy_tree)).to be_empty
    end
  end

  describe 'GET #show' do
    before do
      teammate.update!(can_manage_departments_and_teams: true)
    end

    it 'loads seats, position types, assignments, abilities, and playbooks' do
      title = create(:title, organization: department)
      seat = create(:seat, title: title)
      assignment = create(:assignment, company: organization, department: department)
      ability = create(:ability, organization: department)
      playbook = create(:huddle_playbook, company: department)
      
      get :show, params: { organization_id: organization.id, id: department.id }
      
      expect(response).to be_successful
      expect(assigns(:seats)).to include(seat)
      expect(assigns(:titles)).to include(title)
      expect(assigns(:assignments)).to include(assignment)
      expect(assigns(:abilities)).to include(ability)
      expect(assigns(:huddle_playbooks)).to include(playbook)
    end
  end

  describe 'GET #new' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'renders new form' do
        get :new, params: { organization_id: organization.id, type: 'Department' }
        expect(response).to be_successful
      end
    end

    context 'without permission' do
      before do
        teammate.update!(
          can_manage_departments_and_teams: false,
          can_manage_employment: false
        )
        teammate.reload
        # Clear all caches
        controller.instance_variable_set(:@current_company_teammate, nil)
        CompanyTeammate.connection.clear_query_cache
      end

      it 'redirects to root with alert when type is set' do
        get :new, params: { organization_id: organization.id, type: 'Department' }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'POST #create' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'creates a new department' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            organization: { name: 'New Department', type: 'Department', parent_id: organization.id }
          }
        }.to change { Organization.departments.active.count }.by(1)
        
        expect(response).to redirect_to(organization_departments_path(organization))
        created_dept = Organization.departments.active.find_by(name: 'New Department')
        expect(created_dept).to be_present
        expect(created_dept.type).to eq('Department')
      end

      # NOTE: STI Team has been removed. Team type requests are converted to Department.
      # For actual teams, use the new Team model via /organizations/:id/teams
      it 'converts Team type requests to Department' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            organization: { name: 'New Team', type: 'Team', parent_id: organization.id }
          }
        }.to change { Organization.departments.active.count }.by(1)
        
        expect(response).to redirect_to(organization_departments_path(organization))
        # Team type is converted to Department
        created_dept = Organization.departments.active.find_by(name: 'New Team')
        expect(created_dept).to be_present
        expect(created_dept.type).to eq('Department')
      end

      # NOTE: Type now defaults to 'Department' when missing or blank
      it 'defaults to Department when type is missing' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            organization: { name: 'New Department', parent_id: organization.id }
          }
        }.to change { Organization.departments.active.count }.by(1)
        
        expect(response).to redirect_to(organization_departments_path(organization))
        created_dept = Organization.departments.active.find_by(name: 'New Department')
        expect(created_dept).to be_present
        expect(created_dept.type).to eq('Department')
      end

      it 'defaults to Department when type is blank' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            organization: { name: 'New Department', type: '', parent_id: organization.id }
          }
        }.to change { Organization.departments.active.count }.by(1)
        
        expect(response).to redirect_to(organization_departments_path(organization))
        created_dept = Organization.departments.active.find_by(name: 'New Department')
        expect(created_dept).to be_present
        expect(created_dept.type).to eq('Department')
      end
    end

    context 'without permission' do
      before do
        teammate.update!(
          can_manage_departments_and_teams: false,
          can_manage_employment: false
        )
        teammate.reload
        # Clear controller cache
        controller.instance_variable_set(:@current_company_teammate, nil)
        CompanyTeammate.connection.clear_query_cache
      end

      it 'redirects to root with alert' do
        post :create, params: {
          organization_id: organization.id,
          organization: { name: 'New Department', type: 'Department', parent_id: organization.id }
        }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'GET #edit' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'renders edit form' do
        get :edit, params: { organization_id: organization.id, id: department.id }
        expect(response).to be_successful
      end

      it 'sets available parents ordered by type and name' do
        dept_a = create(:organization, :department, parent: organization, name: 'A Department')
        dept_z = create(:organization, :department, parent: organization, name: 'Z Department')
        dept_b = create(:organization, :department, parent: organization, name: 'B Department')
        
        get :edit, params: { organization_id: organization.id, id: nested_department.id }
        
        available_parents = assigns(:available_parents)
        expect(available_parents).to be_present
        # Should be ordered: Company first, then Departments alphabetically
        # Company should be first
        expect(available_parents.first.id).to eq(organization.id)
        # Within departments, should be alphabetical
        depts = available_parents.select(&:department?)
        expect(depts.map(&:name)).to eq(depts.map(&:name).sort)
      end

      it 'excludes self and descendants from available parents' do
        department2 = create(:organization, :department, parent: department)
        
        get :edit, params: { organization_id: organization.id, id: department.id }
        
        available_parents = assigns(:available_parents)
        expect(available_parents.map(&:id)).not_to include(department.id)
        expect(available_parents.map(&:id)).not_to include(department2.id)
      end
    end

    context 'without permission' do
      before do
        teammate.update!(
          can_manage_departments_and_teams: false,
          can_manage_employment: false
        )
        teammate.reload
        # Clear controller cache
        controller.instance_variable_set(:@current_company_teammate, nil)
        CompanyTeammate.connection.clear_query_cache
      end

      it 'redirects to root with alert' do
        get :edit, params: { organization_id: organization.id, id: department.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'PATCH #update' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'updates department name' do
        patch :update, params: {
          organization_id: organization.id,
          id: department.id,
          organization: { name: 'Updated Department Name' }
        }
        
        department.reload
        expect(response).to redirect_to(organization_department_path(organization, department))
        expect(department.name).to eq('Updated Department Name')
      end

      it 'updates parent organization and persists the change' do
        department2 = create(:organization, :department, parent: organization)
        original_parent_id = department.parent_id
        
        expect {
          patch :update, params: {
            organization_id: organization.id,
            id: department.id,
            organization: { name: department.name, parent_id: department2.id }
          }
        }.to change { department.reload.parent_id }.from(original_parent_id).to(department2.id)
        
        expect(response).to redirect_to(organization_department_path(organization, department))
        expect(department.reload.parent_id).to eq(department2.id)
      end

      it 'allows changing parent to root company' do
        department2 = create(:organization, :department, parent: department)
        original_parent_id = department2.parent_id
        
        expect {
          patch :update, params: {
            organization_id: organization.id,
            id: department2.id,
            organization: { name: department2.name, parent_id: organization.id }
          }
        }.to change { department2.reload.parent_id }.from(original_parent_id).to(organization.id)
        
        department2.reload
        expect(response).to redirect_to(organization_department_path(organization, department2))
        expect(department2.parent_id).to eq(organization.id)
      end

      it 'handles validation errors and re-renders form with available parents' do
        patch :update, params: {
          organization_id: organization.id,
          id: department.id,
          organization: { name: '' }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(assigns(:available_parents)).to be_present
      end

      it 'does not allow changing organization type' do
        original_type = department.type
        expect(original_type).to eq('Department')
        
        patch :update, params: {
          organization_id: organization.id,
          id: department.id,
          organization: { name: department.name, type: 'Team' }
        }
        
        department.reload
        expect(department.type).to eq(original_type)
        expect(department.type).not_to eq('Team')
        expect(response).to redirect_to(organization_department_path(organization, department))
      end

      it 'allows changing name' do
        patch :update, params: {
          organization_id: organization.id,
          id: department.id,
          organization: { name: 'New Department Name' }
        }
        
        department.reload
        expect(department.name).to eq('New Department Name')
        expect(response).to redirect_to(organization_department_path(organization, department))
      end

      it 'allows changing parent organization' do
        department2 = create(:organization, :department, parent: organization)
        original_parent_id = department.parent_id
        
        patch :update, params: {
          organization_id: organization.id,
          id: department.id,
          organization: { name: department.name, parent_id: department2.id }
        }
        
        department.reload
        expect(department.parent_id).to eq(department2.id)
        expect(department.parent_id).not_to eq(original_parent_id)
        expect(response).to redirect_to(organization_department_path(organization, department))
      end
    end

    context 'without permission' do
      before do
        teammate.update!(
          can_manage_departments_and_teams: false,
          can_manage_employment: false
        )
        teammate.reload
        # Clear controller cache
        controller.instance_variable_set(:@current_company_teammate, nil)
        CompanyTeammate.connection.clear_query_cache
      end

      it 'redirects to root with alert' do
        patch :update, params: {
          organization_id: organization.id,
          id: department.id,
          organization: { name: 'Updated Name' }
        }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'PATCH #archive' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'archives the department' do
        expect(department.deleted_at).to be_nil
        
        patch :archive, params: { organization_id: organization.id, id: department.id }
        
        expect(department.reload.deleted_at).to be_present
        expect(response).to redirect_to(organization_departments_path(organization))
      end
    end

    context 'without permission' do
      before do
        teammate.update!(
          can_manage_departments_and_teams: false,
          can_manage_employment: false
        )
        teammate.reload
        # Clear controller cache
        controller.instance_variable_set(:@current_company_teammate, nil)
        CompanyTeammate.connection.clear_query_cache
      end

      it 'redirects to root with alert' do
        patch :archive, params: { organization_id: organization.id, id: department.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end
end
