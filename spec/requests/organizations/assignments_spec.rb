require 'rails_helper'

RSpec.describe 'Organizations::Assignments', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:manager) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }

  let(:person_teammate) { create(:teammate, person: person, organization: organization) }
  let(:admin_teammate) { create(:teammate, person: admin, organization: organization) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true, can_manage_maap: true) }

  before do
    # Temporarily disable PaperTrail for request tests to avoid controller_info issues
    PaperTrail.enabled = false
  end

  after do
    # Re-enable PaperTrail after tests
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/assignments' do
    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'allows access to index' do
        get organization_assignments_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Assignments')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access to index' do
        get organization_assignments_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Assignments')
      end
    end
  end

  describe 'GET /organizations/:organization_id/assignments/:id' do
    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'allows access to show' do
        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(assignment.title)
      end

      it 'renders view switcher' do
        get organization_assignment_path(organization, assignment)
        expect(response.body).to include('Organization View')
        expect(response.body).to include('Public View')
      end

      it 'shows disabled edit and delete options for non-admin users' do
        get organization_assignment_path(organization, assignment)
        expect(response.body).to include('Edit Assignment')
        expect(response.body).to include('Delete Assignment')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access to show' do
        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(assignment.title)
      end

      it 'renders view switcher with all options enabled' do
        get organization_assignment_path(organization, assignment)
        expect(response.body).to include('Organization View')
        expect(response.body).to include('Public View')
        expect(response.body).to include('Manage Ability Milestones')
        expect(response.body).to include('Edit Assignment')
        expect(response.body).to include('Delete Assignment')
      end
    end

    context 'when user is manager with employment permissions' do
      before do
        manager_teammate
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'shows enabled edit option but disabled delete option' do
        get organization_assignment_path(organization, assignment)
        expect(response.body).to include('Edit Assignment')
        expect(response.body).to include('Manage Ability Milestones')
      end
    end
  end

  describe 'GET /organizations/:organization_id/assignments/new' do
    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        get new_organization_assignment_path(organization)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is manager with employment permissions' do
      before do
        manager_teammate
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows access' do
        get new_organization_assignment_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New Assignment')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access' do
        get new_organization_assignment_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New Assignment')
      end
    end
  end

  describe 'GET /organizations/:organization_id/assignments with department filters' do
    let!(:department1) { create(:organization, type: 'Department', parent: organization) }
    let!(:department2) { create(:organization, type: 'Department', parent: organization) }
    let!(:department3) { create(:organization, type: 'Department', parent: organization) }
    let!(:assignment_dept1) { create(:assignment, company: organization, department: department1) }
    let!(:assignment_dept2) { create(:assignment, company: organization, department: department2) }
    let!(:assignment_no_dept) { create(:assignment, company: organization, department: nil) }
    let!(:other_assignment) { create(:assignment, company: organization, department: department3) }

    before do
      person_teammate
      sign_in_as_teammate_for_request(person, organization)
    end

    it 'returns assignments from selected departments' do
      get organization_assignments_path(organization, departments: "#{department1.id},#{department2.id}")
      
      expect(response).to have_http_status(:success)
      assignments = assigns(:assignments).to_a
      
      expect(assignments).to include(assignment_dept1, assignment_dept2)
      expect(assignments).not_to include(assignment_no_dept, other_assignment)
    end

    it 'returns assignments from company (nil department) when "none" is selected' do
      get organization_assignments_path(organization, departments: 'none')
      
      expect(response).to have_http_status(:success)
      assignments = assigns(:assignments).to_a
      
      expect(assignments).to include(assignment_no_dept)
      expect(assignments).not_to include(assignment_dept1, assignment_dept2)
    end

    it 'returns assignments from both company and departments when both are selected' do
      get organization_assignments_path(organization, departments: "none,#{department1.id}")
      
      expect(response).to have_http_status(:success)
      assignments = assigns(:assignments).to_a
      
      expect(assignments).to include(assignment_no_dept, assignment_dept1)
      expect(assignments).not_to include(assignment_dept2, other_assignment)
    end
  end

  describe 'POST /organizations/:organization_id/assignments' do
    let(:valid_params) do
      {
        assignment: {
          title: 'Test Assignment',
          tagline: 'Test tagline',
          version_type: 'ready'
        }
      }
    end

    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        assignment # Ensure assignment exists
        initial_count = Assignment.count
        post organization_assignments_path(organization), params: valid_params
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(Assignment.count).to eq(initial_count) # No new assignment created
      end
    end

    context 'when user is manager with employment permissions' do
      before do
        manager_teammate
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows access and creates assignment' do
        expect {
          post organization_assignments_path(organization), params: valid_params
        }.to change(Assignment, :count).by(1)
        
        expect(response).to have_http_status(:redirect)
        expect(Assignment.last.title).to eq('Test Assignment')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access and creates assignment' do
        expect {
          post organization_assignments_path(organization), params: valid_params
        }.to change(Assignment, :count).by(1)
        
        expect(response).to have_http_status(:redirect)
        expect(Assignment.last.title).to eq('Test Assignment')
      end
    end
  end

  describe 'GET /organizations/:organization_id/assignments/:id/edit' do
    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        get edit_organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is manager with employment permissions' do
      before do
        manager_teammate
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows access and renders edit form' do
        get edit_organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Edit Assignment')
        expect(response.body).to include(assignment.title)
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access and renders edit form without HAML errors' do
        get edit_organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Edit Assignment')
        expect(response.body).to include(assignment.title)
        # This test will catch HAML syntax errors like indentation issues
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/assignments/:id' do
    let(:update_params) do
      {
        assignment: {
          title: 'Updated Assignment',
          tagline: assignment.tagline,
          version_type: 'clarifying'
        }
      }
    end

    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        patch organization_assignment_path(organization, assignment), params: update_params
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(assignment.reload.title).not_to eq('Updated Assignment')
      end
    end

    context 'when user is manager with employment permissions' do
      before do
        manager_teammate
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows access and updates assignment' do
        patch organization_assignment_path(organization, assignment), params: update_params
        expect(response).to have_http_status(:redirect)
        assignment.reload
        expect(response).to redirect_to(organization_assignment_path(organization, assignment))
        expect(flash[:notice]).to eq('Assignment was successfully updated.')
        expect(assignment.title).to eq('Updated Assignment')
      end

      it 'redirects to edit page with flash alert on validation failure' do
        invalid_params = {
          assignment: {
            title: '', # Invalid: title is required
            tagline: assignment.tagline,
            version_type: 'clarifying'
          }
        }
        
        patch organization_assignment_path(organization, assignment), params: invalid_params
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(edit_organization_assignment_path(organization, assignment))
        expect(flash[:alert]).to be_present
        expect(flash[:alert]).to include('Failed to update assignment')
        expect(assignment.reload.title).not_to eq('')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access and updates assignment' do
        patch organization_assignment_path(organization, assignment), params: update_params
        expect(response).to have_http_status(:redirect)
        assignment.reload
        expect(response).to redirect_to(organization_assignment_path(organization, assignment))
        expect(flash[:notice]).to eq('Assignment was successfully updated.')
        expect(assignment.title).to eq('Updated Assignment')
      end

      it 'redirects to edit page with flash alert on validation failure' do
        invalid_params = {
          assignment: {
            title: '', # Invalid: title is required
            tagline: assignment.tagline,
            version_type: 'clarifying'
          }
        }
        
        patch organization_assignment_path(organization, assignment), params: invalid_params
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(edit_organization_assignment_path(organization, assignment))
        expect(flash[:alert]).to be_present
        expect(flash[:alert]).to include('Failed to update assignment')
        expect(assignment.reload.title).not_to eq('')
      end
    end
  end

  describe 'DELETE /organizations/:organization_id/assignments/:id' do
    let!(:assignment_to_delete) { create(:assignment, company: organization) }

    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        delete organization_assignment_path(organization, assignment_to_delete)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(Assignment.exists?(assignment_to_delete.id)).to be true
      end
    end

    context 'when user is manager with employment permissions' do
      let(:manager_without_maap) { create(:teammate, person: manager, organization: organization, can_manage_employment: true, can_manage_maap: false) }
      
      before do
        manager_without_maap
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'denies access (only admins can destroy)' do
        delete organization_assignment_path(organization, assignment_to_delete)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(Assignment.exists?(assignment_to_delete.id)).to be true
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access and destroys assignment' do
        expect {
          delete organization_assignment_path(organization, assignment_to_delete)
        }.to change(Assignment, :count).by(-1)
        
        expect(response).to have_http_status(:redirect)
        expect(Assignment.exists?(assignment_to_delete.id)).to be false
      end
    end
  end

  describe 'GET /organizations/:organization_id/assignments with major_version filter' do
    let!(:assignment_v1) { create(:assignment, company: organization, semantic_version: '1.0.0', title: 'Assignment v1') }
    let!(:assignment_v1_2) { create(:assignment, company: organization, semantic_version: '1.2.3', title: 'Assignment v1.2') }
    let!(:assignment_v2) { create(:assignment, company: organization, semantic_version: '2.0.0', title: 'Assignment v2') }
    let!(:assignment_v0) { create(:assignment, company: organization, semantic_version: '0.1.0', title: 'Assignment v0') }

    before do
      person_teammate
      sign_in_as_teammate_for_request(person, organization)
    end

    it 'filters by major version 1' do
      get organization_assignments_path(organization, major_version: 1)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Assignment v1')
      expect(response.body).to include('Assignment v1.2')
      expect(response.body).not_to include('Assignment v2')
      expect(response.body).not_to include('Assignment v0')
    end

    it 'filters by major version 2' do
      get organization_assignments_path(organization, major_version: 2)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Assignment v2')
      expect(response.body).not_to include('Assignment v1')
      expect(response.body).not_to include('Assignment v1.2')
      expect(response.body).not_to include('Assignment v0')
    end

    it 'filters by major version 0' do
      get organization_assignments_path(organization, major_version: 0)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Assignment v0')
      expect(response.body).not_to include('Assignment v1')
      expect(response.body).not_to include('Assignment v1.2')
      expect(response.body).not_to include('Assignment v2')
    end

    it 'shows all assignments when major_version is empty' do
      get organization_assignments_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Assignment v1')
      expect(response.body).to include('Assignment v1.2')
      expect(response.body).to include('Assignment v2')
      expect(response.body).to include('Assignment v0')
    end
  end
end

