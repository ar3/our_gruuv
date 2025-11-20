require 'rails_helper'

RSpec.describe 'Organizations::Assignments', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:manager) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }

  let(:person_teammate) { create(:teammate, person: person, organization: organization) }
  let(:admin_teammate) { create(:teammate, person: admin, organization: organization) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true) }

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
        expect(assignment.reload.title).to eq('Updated Assignment')
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
        expect(assignment.reload.title).to eq('Updated Assignment')
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
      before do
        manager_teammate
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
end

