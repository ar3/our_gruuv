require 'rails_helper'

RSpec.describe Organizations::DepartmentsController, type: :controller do
  let(:organization) { create(:company) }
  let(:department) { create(:department, company: organization) }
  let(:nested_department) { create(:department, company: organization, parent_department: department, name: 'Nested Dept') }
  let(:current_person) { create(:person, og_admin: false) }
  let(:teammate) do
    existing = CompanyTeammate.find_by(person: current_person, organization: organization)
    existing || create(:teammate, person: current_person, organization: organization)
  end

  before do
    teammate # Ensure teammate exists
    sign_in_as_teammate(current_person, organization)
    allow(controller).to receive(:set_organization).and_return(true)
    controller.instance_variable_set(:@organization, organization)
  end

  describe 'GET #index' do
    it 'loads active departments' do
      department
      nested_department
      
      get :index, params: { organization_id: organization.id }
      
      expect(response).to be_successful
      expect(assigns(:departments)).to be_present
      expect(assigns(:hierarchy_tree)).to be_present
    end

    it 'excludes archived departments' do
      archived_dept = create(:department, company: organization, deleted_at: Time.current)
      department
      
      get :index, params: { organization_id: organization.id }
      
      expect(assigns(:departments).map(&:id)).to include(department.id)
      expect(assigns(:departments).map(&:id)).not_to include(archived_dept.id)
    end

    it 'handles empty departments gracefully' do
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

    it 'loads titles, assignments, abilities, and aspirations for the department' do
      title = create(:title, company: organization, department: department)
      assignment = create(:assignment, company: organization, department: department)
      ability = create(:ability, company: organization, department: department)
      aspiration = create(:aspiration, company: organization, department: department)
      
      get :show, params: { organization_id: organization.id, id: department.id }
      
      expect(response).to be_successful
      expect(assigns(:titles)).to include(title)
      expect(assigns(:assignments)).to include(assignment)
      expect(assigns(:abilities)).to include(ability)
      expect(assigns(:aspirations)).to include(aspiration)
    end

    it 'loads child departments' do
      nested_department
      
      get :show, params: { organization_id: organization.id, id: department.id }
      
      expect(response).to be_successful
      expect(assigns(:child_departments)).to include(nested_department)
    end
  end

  describe 'GET #new' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'renders new form' do
        get :new, params: { organization_id: organization.id }
        expect(response).to be_successful
      end

      it 'sets parent department when provided' do
        department
        get :new, params: { organization_id: organization.id, parent_department_id: department.id }
        
        expect(assigns(:department).parent_department).to eq(department)
      end
    end

    context 'without permission' do
      before do
        teammate.update!(
          can_manage_departments_and_teams: false,
          can_manage_employment: false
        )
        teammate.reload
        controller.instance_variable_set(:@current_company_teammate, nil)
      end

      it 'redirects to root with alert' do
        get :new, params: { organization_id: organization.id }
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
            department: { name: 'New Department' }
          }
        }.to change { Department.count }.by(1)
        
        expect(response).to redirect_to(organization_departments_path(organization))
        created_dept = Department.find_by(name: 'New Department')
        expect(created_dept).to be_present
        expect(created_dept.company_id).to eq(organization.id)
      end

      it 'creates a nested department with parent' do
        department
        expect {
          post :create, params: {
            organization_id: organization.id,
            department: { name: 'Nested New', parent_department_id: department.id }
          }
        }.to change { Department.count }.by(1)
        
        created_dept = Department.find_by(name: 'Nested New')
        expect(created_dept.parent_department).to eq(department)
      end
    end

    context 'without permission' do
      before do
        teammate.update!(
          can_manage_departments_and_teams: false,
          can_manage_employment: false
        )
        teammate.reload
        controller.instance_variable_set(:@current_company_teammate, nil)
      end

      it 'redirects to root with alert' do
        post :create, params: {
          organization_id: organization.id,
          department: { name: 'New Department' }
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

      it 'sets available parents excluding self and descendants' do
        department
        nested_department
        other_dept = create(:department, company: organization, name: 'Other Dept')
        
        get :edit, params: { organization_id: organization.id, id: department.id }
        
        available_parents = assigns(:available_parents)
        expect(available_parents).to include(other_dept)
        expect(available_parents).not_to include(department)
        expect(available_parents).not_to include(nested_department)
      end
    end

    context 'without permission' do
      before do
        teammate.update!(
          can_manage_departments_and_teams: false,
          can_manage_employment: false
        )
        teammate.reload
        controller.instance_variable_set(:@current_company_teammate, nil)
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
          department: { name: 'Updated Department Name' }
        }
        
        department.reload
        expect(response).to redirect_to(organization_department_path(organization, department))
        expect(department.name).to eq('Updated Department Name')
      end

      it 'updates parent department' do
        other_dept = create(:department, company: organization)
        
        patch :update, params: {
          organization_id: organization.id,
          id: department.id,
          department: { parent_department_id: other_dept.id }
        }
        
        department.reload
        expect(department.parent_department).to eq(other_dept)
      end

      it 'prevents circular references' do
        nested_department
        original_parent = department.parent_department_id
        
        patch :update, params: {
          organization_id: organization.id,
          id: department.id,
          department: { parent_department_id: nested_department.id }
        }
        
        department.reload
        expect(department.parent_department_id).to eq(original_parent)
      end
    end

    context 'without permission' do
      before do
        teammate.update!(
          can_manage_departments_and_teams: false,
          can_manage_employment: false
        )
        teammate.reload
        controller.instance_variable_set(:@current_company_teammate, nil)
      end

      it 'redirects to root with alert' do
        patch :update, params: {
          organization_id: organization.id,
          id: department.id,
          department: { name: 'Updated Name' }
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
        controller.instance_variable_set(:@current_company_teammate, nil)
      end

      it 'redirects to root with alert' do
        patch :archive, params: { organization_id: organization.id, id: department.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  # Association actions
  describe 'GET #associate_abilities' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'loads unassociated abilities' do
        unassociated_ability = create(:ability, company: organization, department: nil)
        associated_ability = create(:ability, company: organization, department: department)
        
        get :associate_abilities, params: { organization_id: organization.id, id: department.id }
        
        expect(response).to be_successful
        expect(assigns(:unassociated_abilities)).to include(unassociated_ability)
        expect(assigns(:unassociated_abilities)).not_to include(associated_ability)
      end

      it 'only includes abilities from the same company' do
        other_company = create(:company)
        other_ability = create(:ability, company: other_company, department: nil)
        company_ability = create(:ability, company: organization, department: nil)
        
        get :associate_abilities, params: { organization_id: organization.id, id: department.id }
        
        expect(assigns(:unassociated_abilities)).to include(company_ability)
        expect(assigns(:unassociated_abilities)).not_to include(other_ability)
      end
    end

    context 'without permission' do
      before do
        teammate.update!(
          can_manage_departments_and_teams: false,
          can_manage_employment: false
        )
        teammate.reload
        controller.instance_variable_set(:@current_company_teammate, nil)
      end

      it 'redirects to root with alert' do
        get :associate_abilities, params: { organization_id: organization.id, id: department.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'PATCH #update_abilities_association' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'associates selected abilities with the department' do
        ability1 = create(:ability, company: organization, department: nil)
        ability2 = create(:ability, company: organization, department: nil)
        ability3 = create(:ability, company: organization, department: nil)
        
        patch :update_abilities_association, params: {
          organization_id: organization.id,
          id: department.id,
          ability_ids: [ability1.id, ability2.id]
        }
        
        expect(ability1.reload.department).to eq(department)
        expect(ability2.reload.department).to eq(department)
        expect(ability3.reload.department).to be_nil
        expect(response).to redirect_to(organization_department_path(organization, department))
        expect(flash[:notice]).to include('2')
        expect(flash[:notice]).to include('abilities')
      end

      it 'does not associate abilities from other companies' do
        other_company = create(:company)
        other_ability = create(:ability, company: other_company, department: nil)
        
        patch :update_abilities_association, params: {
          organization_id: organization.id,
          id: department.id,
          ability_ids: [other_ability.id]
        }
        
        expect(other_ability.reload.department).to be_nil
      end

      it 'does not reassociate already associated abilities' do
        other_dept = create(:department, company: organization)
        already_associated = create(:ability, company: organization, department: other_dept)
        
        patch :update_abilities_association, params: {
          organization_id: organization.id,
          id: department.id,
          ability_ids: [already_associated.id]
        }
        
        expect(already_associated.reload.department).to eq(other_dept)
      end

      it 'handles empty selection gracefully' do
        patch :update_abilities_association, params: {
          organization_id: organization.id,
          id: department.id,
          ability_ids: []
        }
        
        expect(response).to redirect_to(organization_department_path(organization, department))
        expect(flash[:notice]).to include('0')
      end
    end
  end

  describe 'GET #associate_aspirations' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'loads unassociated aspirations' do
        unassociated_aspiration = create(:aspiration, company: organization, department: nil)
        associated_aspiration = create(:aspiration, company: organization, department: department)
        
        get :associate_aspirations, params: { organization_id: organization.id, id: department.id }
        
        expect(response).to be_successful
        expect(assigns(:unassociated_aspirations)).to include(unassociated_aspiration)
        expect(assigns(:unassociated_aspirations)).not_to include(associated_aspiration)
      end
    end
  end

  describe 'PATCH #update_aspirations_association' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'associates selected aspirations with the department' do
        aspiration1 = create(:aspiration, company: organization, department: nil)
        aspiration2 = create(:aspiration, company: organization, department: nil)
        
        patch :update_aspirations_association, params: {
          organization_id: organization.id,
          id: department.id,
          aspiration_ids: [aspiration1.id, aspiration2.id]
        }
        
        expect(aspiration1.reload.department).to eq(department)
        expect(aspiration2.reload.department).to eq(department)
        expect(response).to redirect_to(organization_department_path(organization, department))
      end
    end
  end

  describe 'GET #associate_titles' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'loads unassociated titles' do
        unassociated_title = create(:title, company: organization, department: nil)
        associated_title = create(:title, company: organization, department: department)
        
        get :associate_titles, params: { organization_id: organization.id, id: department.id }
        
        expect(response).to be_successful
        expect(assigns(:unassociated_titles)).to include(unassociated_title)
        expect(assigns(:unassociated_titles)).not_to include(associated_title)
      end
    end
  end

  describe 'PATCH #update_titles_association' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'associates selected titles with the department' do
        title1 = create(:title, company: organization, department: nil)
        title2 = create(:title, company: organization, department: nil)
        
        patch :update_titles_association, params: {
          organization_id: organization.id,
          id: department.id,
          title_ids: [title1.id, title2.id]
        }
        
        expect(title1.reload.department).to eq(department)
        expect(title2.reload.department).to eq(department)
        expect(response).to redirect_to(organization_department_path(organization, department))
      end
    end
  end

  describe 'GET #associate_assignments' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'loads unassociated assignments' do
        unassociated_assignment = create(:assignment, company: organization, department: nil)
        associated_assignment = create(:assignment, company: organization, department: department)
        
        get :associate_assignments, params: { organization_id: organization.id, id: department.id }
        
        expect(response).to be_successful
        expect(assigns(:unassociated_assignments)).to include(unassociated_assignment)
        expect(assigns(:unassociated_assignments)).not_to include(associated_assignment)
      end

      it 'only includes assignments from the same company' do
        other_company = create(:company)
        other_assignment = create(:assignment, company: other_company, department: nil)
        company_assignment = create(:assignment, company: organization, department: nil)
        
        get :associate_assignments, params: { organization_id: organization.id, id: department.id }
        
        expect(assigns(:unassociated_assignments)).to include(company_assignment)
        expect(assigns(:unassociated_assignments)).not_to include(other_assignment)
      end
    end

    context 'without permission' do
      before do
        teammate.update!(
          can_manage_departments_and_teams: false,
          can_manage_employment: false
        )
        teammate.reload
        controller.instance_variable_set(:@current_company_teammate, nil)
      end

      it 'redirects to root with alert' do
        get :associate_assignments, params: { organization_id: organization.id, id: department.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'PATCH #update_assignments_association' do
    context 'with permission' do
      before do
        teammate.update!(can_manage_departments_and_teams: true)
      end

      it 'associates selected assignments with the department' do
        assignment1 = create(:assignment, company: organization, department: nil)
        assignment2 = create(:assignment, company: organization, department: nil)
        assignment3 = create(:assignment, company: organization, department: nil)
        
        patch :update_assignments_association, params: {
          organization_id: organization.id,
          id: department.id,
          assignment_ids: [assignment1.id, assignment2.id]
        }
        
        expect(assignment1.reload.department).to eq(department)
        expect(assignment2.reload.department).to eq(department)
        expect(assignment3.reload.department).to be_nil
        expect(response).to redirect_to(organization_department_path(organization, department))
        expect(flash[:notice]).to include('2')
        expect(flash[:notice]).to include('assignments')
      end

      it 'does not associate assignments from other companies' do
        other_company = create(:company)
        other_assignment = create(:assignment, company: other_company, department: nil)
        
        patch :update_assignments_association, params: {
          organization_id: organization.id,
          id: department.id,
          assignment_ids: [other_assignment.id]
        }
        
        expect(other_assignment.reload.department).to be_nil
      end

      it 'does not reassociate already associated assignments' do
        other_dept = create(:department, company: organization)
        already_associated = create(:assignment, company: organization, department: other_dept)
        
        patch :update_assignments_association, params: {
          organization_id: organization.id,
          id: department.id,
          assignment_ids: [already_associated.id]
        }
        
        expect(already_associated.reload.department).to eq(other_dept)
      end

      it 'handles empty selection gracefully' do
        patch :update_assignments_association, params: {
          organization_id: organization.id,
          id: department.id,
          assignment_ids: []
        }
        
        expect(response).to redirect_to(organization_department_path(organization, department))
        expect(flash[:notice]).to include('0')
      end
    end
  end
end
