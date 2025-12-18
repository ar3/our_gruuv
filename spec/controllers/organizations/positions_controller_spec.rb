require 'rails_helper'

RSpec.describe Organizations::PositionsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, :company) }
  let(:position_type) { create(:position_type, organization: organization) }
  let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }

  before do
    create(:teammate, person: person, organization: organization)
    sign_in_as_teammate(person, organization)
  end

  describe 'GET #index' do
    let!(:position_level_1) { create(:position_level, position_major_level: position_type.position_major_level, level: '1.1') }
    let!(:position_level_2) { create(:position_level, position_major_level: position_type.position_major_level, level: '1.2') }
    let!(:position_level_3) { create(:position_level, position_major_level: position_type.position_major_level, level: '1.3') }
    let!(:position_level_4) { create(:position_level, position_major_level: position_type.position_major_level, level: '2.1') }
    
    let!(:position_v1) { create(:position, position_type: position_type, position_level: position_level_1, semantic_version: '1.0.0') }
    let!(:position_v1_2) { create(:position, position_type: position_type, position_level: position_level_2, semantic_version: '1.2.3') }
    let!(:position_v2) { create(:position, position_type: position_type, position_level: position_level_3, semantic_version: '2.0.0') }
    let!(:position_v0) { create(:position, position_type: position_type, position_level: position_level_4, semantic_version: '0.1.0') }

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

    it 'combines major_version filter with position_type filter' do
      other_position_type = create(:position_type, organization: organization)
      other_position_level = create(:position_level, position_major_level: other_position_type.position_major_level)
      other_position = create(:position, position_type: other_position_type, position_level: other_position_level, semantic_version: '1.0.0')

      get :index, params: { organization_id: organization.id, major_version: 1, position_type: position_type.id }
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
  end

  describe 'GET #manage_assignments' do
    let(:position) { create(:position, position_type: position_type, position_level: position_level) }
    let(:assignment) { create(:assignment, company: organization) }

    before do
      # Update existing teammate to have permission
      teammate = Teammate.find_by(person: person, organization: organization)
      teammate.update(can_manage_employment: true)
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

    it 'requires update permission' do
      teammate = Teammate.find_by(person: person, organization: organization)
      teammate.update(can_manage_employment: false)
      
      get :manage_assignments, params: { organization_id: organization.id, id: position.id }
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
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
    let(:position) { create(:position, position_type: position_type, position_level: position_level) }
    let(:assignment) { create(:assignment, company: organization) }

    before do
      # Update existing teammate to have permission
      teammate = Teammate.find_by(person: person, organization: organization)
      teammate.update(can_manage_employment: true)
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
            anticipated_energy_percentage: '30',
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
      teammate.update(can_manage_employment: false)
      
      patch :update_assignments, params: {
        organization_id: organization.id,
        id: position.id,
        position_assignments: {}
      }
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end
  end
end

