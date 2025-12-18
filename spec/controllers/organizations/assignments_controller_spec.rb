require 'rails_helper'

RSpec.describe Organizations::AssignmentsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, :company) }
  let(:maap_person) { create(:person) }
  let(:no_permission_person) { create(:person) }

  before do
    create(:teammate, person: person, organization: organization, can_manage_employment: true)
    create(:teammate, person: maap_person, organization: organization, can_manage_maap: true)
    create(:teammate, person: no_permission_person, organization: organization)
    sign_in_as_teammate(person, organization)
  end

  describe 'GET #index' do
    let!(:assignment_v1) { create(:assignment, company: organization, semantic_version: '1.0.0', title: 'Assignment v1') }
    let!(:assignment_v1_2) { create(:assignment, company: organization, semantic_version: '1.2.3', title: 'Assignment v1.2') }
    let!(:assignment_v2) { create(:assignment, company: organization, semantic_version: '2.0.0', title: 'Assignment v2') }
    let!(:assignment_v0) { create(:assignment, company: organization, semantic_version: '0.1.0', title: 'Assignment v0') }

    it 'returns all assignments when no filters applied' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:assignments)).to include(assignment_v1, assignment_v1_2, assignment_v2, assignment_v0)
    end

    it 'filters by major version 1' do
      get :index, params: { organization_id: organization.id, major_version: 1 }
      assignments = assigns(:assignments)
      expect(assignments).to include(assignment_v1, assignment_v1_2)
      expect(assignments).not_to include(assignment_v2, assignment_v0)
    end

    it 'filters by major version 2' do
      get :index, params: { organization_id: organization.id, major_version: 2 }
      assignments = assigns(:assignments)
      expect(assignments).to include(assignment_v2)
      expect(assignments).not_to include(assignment_v1, assignment_v1_2, assignment_v0)
    end

    it 'filters by major version 0' do
      get :index, params: { organization_id: organization.id, major_version: 0 }
      assignments = assigns(:assignments)
      expect(assignments).to include(assignment_v0)
      expect(assignments).not_to include(assignment_v1, assignment_v1_2, assignment_v2)
    end

    it 'returns empty result when filtering for non-existent major version' do
      get :index, params: { organization_id: organization.id, major_version: 99 }
      expect(assigns(:assignments)).to be_empty
    end

    it 'combines major_version filter with company filter' do
      other_company = create(:organization, :company)
      other_assignment = create(:assignment, company: other_company, semantic_version: '1.0.0')

      get :index, params: { organization_id: organization.id, major_version: 1, company: organization.id }
      assignments = assigns(:assignments)
      expect(assignments).to include(assignment_v1, assignment_v1_2)
      expect(assignments).not_to include(other_assignment, assignment_v2, assignment_v0)
    end

    it 'combines major_version filter with sorting' do
      get :index, params: { organization_id: organization.id, major_version: 1, sort: 'title' }
      assignments = assigns(:assignments)
      expect(assignments).to include(assignment_v1, assignment_v1_2)
      expect(assignments.length).to eq(2)
    end
  end

  describe 'POST #create' do
    context 'when user has MAAP permissions' do
      before do
        sign_in_as_teammate(maap_person, organization)
      end

      let(:valid_attributes) do
        {
          title: 'Test Assignment',
          tagline: 'A test assignment',
          required_activities: 'Some activities',
          handbook: 'Some handbook content',
          version_type: 'ready'
        }
      end

      it 'allows creating an assignment' do
        expect {
          post :create, params: { organization_id: organization.id, assignment: valid_attributes }
        }.to change(Assignment, :count).by(1)
        
        expect(response).to redirect_to(organization_assignment_path(organization, Assignment.last))
      end
    end

    context 'when user lacks MAAP permissions' do
      before do
        sign_in_as_teammate(no_permission_person, organization)
      end

      let(:valid_attributes) do
        {
          title: 'Test Assignment',
          tagline: 'A test assignment',
          required_activities: 'Some activities',
          handbook: 'Some handbook content',
          version_type: 'ready'
        }
      end

      it 'denies creating an assignment' do
        post :create, params: { organization_id: organization.id, assignment: valid_attributes }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
      end
    end
  end

  describe 'PATCH #update' do
    let!(:assignment) { create(:assignment, company: organization, title: 'Original Title') }

    context 'when user has MAAP permissions' do
      before do
        sign_in_as_teammate(maap_person, organization)
      end

      it 'allows updating an assignment' do
        patch :update, params: {
          organization_id: organization.id,
          id: assignment.id,
          assignment: { title: 'Updated Title', tagline: assignment.tagline, version_type: 'insignificant' }
        }
        
        assignment.reload
        expect(assignment.title).to eq('Updated Title')
        expect(response).to redirect_to(organization_assignment_path(organization, assignment))
      end
    end

    context 'when user lacks MAAP permissions' do
      before do
        sign_in_as_teammate(no_permission_person, organization)
      end

      it 'denies updating an assignment' do
        patch :update, params: {
          organization_id: organization.id,
          id: assignment.id,
          assignment: { title: 'Updated Title', tagline: assignment.tagline, version_type: 'insignificant' }
        }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:assignment) { create(:assignment, company: organization) }

    context 'when user has MAAP permissions' do
      before do
        sign_in_as_teammate(maap_person, organization)
      end

      it 'allows destroying an assignment' do
        expect {
          delete :destroy, params: { organization_id: organization.id, id: assignment.id }
        }.to change(Assignment, :count).by(-1)
        
        expect(response).to redirect_to(organization_assignments_path(organization))
      end
    end

    context 'when user lacks MAAP permissions' do
      before do
        sign_in_as_teammate(no_permission_person, organization)
      end

      it 'denies destroying an assignment' do
        delete :destroy, params: { organization_id: organization.id, id: assignment.id }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
      end
    end
  end
end

