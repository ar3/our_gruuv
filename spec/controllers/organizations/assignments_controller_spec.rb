require 'rails_helper'

RSpec.describe Organizations::AssignmentsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, :company) }

  before do
    create(:teammate, person: person, organization: organization, can_manage_employment: true)
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
end

