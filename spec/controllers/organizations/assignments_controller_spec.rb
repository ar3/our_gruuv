require 'rails_helper'

RSpec.describe Organizations::AssignmentsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
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

    it 'filters by multiple companies' do
      other_company = create(:organization)
      other_assignment = create(:assignment, company: other_company, semantic_version: '1.0.0')

      get :index, params: { organization_id: organization.id, company: [organization.id] }
      assignments = assigns(:assignments)
      expect(assignments).to include(assignment_v1, assignment_v1_2, assignment_v2, assignment_v0)
      expect(assignments).not_to include(other_assignment)
    end

    it 'filters by company shows only assignments with nil department' do
      department = create(:department, company: organization)
      assignment_in_dept = create(:assignment, company: organization, department: department, semantic_version: '1.0.0')
      assignment_no_dept = create(:assignment, company: organization, department: nil, semantic_version: '1.0.0')

      get :index, params: { organization_id: organization.id, departments: 'none' }
      assignments = assigns(:assignments)
      # Should only include assignments with nil department (directly on company)
      expect(assignments).to include(assignment_v1, assignment_v1_2, assignment_v2, assignment_v0, assignment_no_dept)
      expect(assignments).not_to include(assignment_in_dept)
    end

    it 'filters by department' do
      department = create(:department, company: organization)
      assignment_in_dept = create(:assignment, company: organization, department: department, semantic_version: '1.0.0')
      assignment_no_dept = create(:assignment, company: organization, department: nil, semantic_version: '1.0.0')

      get :index, params: { organization_id: organization.id, departments: department.id.to_s }
      assignments = assigns(:assignments)
      expect(assignments).to include(assignment_in_dept)
      expect(assignments).not_to include(assignment_no_dept)
    end

    it 'filters by both company and department' do
      department = create(:department, company: organization)
      assignment_in_dept = create(:assignment, company: organization, department: department, semantic_version: '1.0.0')
      assignment_no_dept = create(:assignment, company: organization, department: nil, semantic_version: '1.0.0')

      get :index, params: { organization_id: organization.id, departments: "none,#{department.id}" }
      assignments = assigns(:assignments)
      # Should include assignments with nil department (from company) OR in the department
      expect(assignments).to include(assignment_v1, assignment_v1_2, assignment_v2, assignment_v0, assignment_no_dept, assignment_in_dept)
      # assignment_no_dept should be included because it's in the company with nil department
      expect(assignments).to include(assignment_no_dept)
    end

    it 'filters by outcomes with tri-state filter' do
      assignment_with_outcomes = create(:assignment, company: organization)
      create(:assignment_outcome, assignment: assignment_with_outcomes)
      assignment_without_outcomes = create(:assignment, company: organization)

      get :index, params: { organization_id: organization.id, outcomes_filter: 'with' }
      assignments = assigns(:assignments)
      expect(assignments).to include(assignment_with_outcomes)
      expect(assignments).not_to include(assignment_without_outcomes)
    end

    it 'filters by abilities with tri-state filter' do
      ability = create(:ability, company: organization)
      assignment_with_abilities = create(:assignment, company: organization)
      create(:assignment_ability, assignment: assignment_with_abilities, ability: ability, milestone_level: 1)
      assignment_without_abilities = create(:assignment, company: organization)

      get :index, params: { organization_id: organization.id, abilities_filter: 'with' }
      assignments = assigns(:assignments)
      expect(assignments).to include(assignment_with_abilities)
      expect(assignments).not_to include(assignment_without_abilities)
    end

    it 'combines major_version filter with sorting' do
      get :index, params: { organization_id: organization.id, major_version: 1, sort: 'title' }
      assignments = assigns(:assignments)
      expect(assignments).to include(assignment_v1, assignment_v1_2)
      expect(assignments.length).to eq(2)
    end

    it 'defaults to by_department spotlight when no spotlight parameter is provided' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:current_spotlight)).to eq('by_department')
    end

    it 'calculates spotlight stats for by_department spotlight' do
      get :index, params: { organization_id: organization.id, spotlight: 'by_department' }
      expect(assigns(:spotlight_stats)).to be_a(Hash)
      expect(assigns(:spotlight_stats)).to have_key(:departments)
      expect(assigns(:spotlight_stats)).to have_key(:total_assignments)
      expect(assigns(:spotlight_stats)).to have_key(:total_departments)
      expect(assigns(:spotlight_stats)[:total_assignments]).to eq(4)
      expect(assigns(:spotlight_stats)[:total_departments]).to eq(1)
    end

    it 'groups assignments by department in spotlight stats' do
      department = create(:department, company: organization)
      assignment_with_dept = create(:assignment, company: organization, department: department)
      
      get :index, params: { organization_id: organization.id, spotlight: 'by_department' }
      stats = assigns(:spotlight_stats)
      expect(stats[:departments]).to have_key(nil) # assignments without departments
      expect(stats[:departments]).to have_key(department.id) # assignments with department
      expect(stats[:departments][department.id][:count]).to eq(1)
      expect(stats[:departments][nil][:count]).to eq(4) # the 4 original assignments without departments
    end

    it 'calculates spotlight stats using filtered assignments' do
      department = create(:department, company: organization)
      assignment_with_dept_v1 = create(:assignment, company: organization, department: department, semantic_version: '1.0.0')
      assignment_with_dept_v2 = create(:assignment, company: organization, department: department, semantic_version: '2.0.0')
      
      # Filter by major version 1
      get :index, params: { organization_id: organization.id, spotlight: 'by_department', major_version: 1 }
      stats = assigns(:spotlight_stats)
      # Should only count assignments with version 1.x.x (assignment_v1, assignment_v1_2, assignment_with_dept_v1)
      expect(stats[:total_assignments]).to eq(3)
      expect(stats[:departments][department.id][:count]).to eq(1) # Only the v1 assignment
    end

    it 'calculates spotlight stats using outcomes filter' do
      assignment_with_outcomes = create(:assignment, company: organization)
      create(:assignment_outcome, assignment: assignment_with_outcomes)
      assignment_without_outcomes = create(:assignment, company: organization)
      
      get :index, params: { organization_id: organization.id, spotlight: 'by_department', outcomes_filter: 'with' }
      stats = assigns(:spotlight_stats)
      # Should only count assignments with outcomes
      expect(stats[:total_assignments]).to eq(1)
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

  describe 'GET #show' do
    let!(:assignment) { create(:assignment, company: organization) }
    let!(:consumer1) { create(:assignment, company: organization, title: 'Consumer 1') }
    let!(:consumer2) { create(:assignment, company: organization, title: 'Consumer 2') }

    context 'when user has permission' do
      before do
        sign_in_as_teammate(person, organization)
      end

      it 'loads consumer assignments' do
        AssignmentSupplyRelationship.create!(
          supplier_assignment: assignment,
          consumer_assignment: consumer1
        )
        
        get :show, params: { organization_id: organization.id, id: assignment.id }
        
        expect(assigns(:consumer_assignments)).to include(consumer1)
        expect(assigns(:consumer_assignments)).not_to include(consumer2)
      end

      it 'loads empty consumer assignments when none exist' do
        get :show, params: { organization_id: organization.id, id: assignment.id }
        
        expect(assigns(:consumer_assignments)).to be_empty
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

