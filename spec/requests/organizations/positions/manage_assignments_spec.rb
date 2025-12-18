require 'rails_helper'

RSpec.describe 'Position Assignments Management', type: :request do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: company, can_manage_employment: true) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  
  let(:company_assignment) { create(:assignment, company: company, department: nil) }
  let(:department_assignment) { create(:assignment, company: company, department: department) }
  
  before do
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/positions/:id/manage_assignments' do
    it 'loads assignments grouped by hierarchy' do
      company_assignment
      department_assignment
      
      get manage_assignments_organization_position_path(company, position)
      
      expect(response).to have_http_status(:success)
      assignments = assigns(:assignments)
      expect(assignments.map(&:id)).to include(company_assignment.id, department_assignment.id)
      expect(assigns(:assignments_by_org)).to be_a(Hash)
    end

    it 'requires update permission' do
      teammate.update(can_manage_employment: false)
      
      get manage_assignments_organization_position_path(company, position)
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end

    it 'pre-populates existing position assignments' do
      existing_pa = create(:position_assignment, 
        position: position, 
        assignment: company_assignment,
        min_estimated_energy: 20,
        max_estimated_energy: 40,
        anticipated_energy_percentage: 30,
        assignment_type: 'required'
      )
      
      get manage_assignments_organization_position_path(company, position)
      
      expect(response).to have_http_status(:success)
      expect(assigns(:existing_position_assignments)[company_assignment.id]).to eq(existing_pa)
    end

    it 'returns 404 if position does not exist' do
      get manage_assignments_organization_position_path(company, 99999)
      
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /organizations/:organization_id/positions/:id/update_assignments' do
    it 'creates PositionAssignment when max_estimated_energy > 0' do
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            min_estimated_energy: '20',
            max_estimated_energy: '40',
            anticipated_energy_percentage: '30',
            assignment_type: 'required'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      expect(flash[:notice]).to be_present
      
      pa = PositionAssignment.find_by(position: position, assignment: company_assignment)
      expect(pa).to be_present
      expect(pa.min_estimated_energy).to eq(20)
      expect(pa.max_estimated_energy).to eq(40)
      expect(pa.anticipated_energy_percentage).to eq(30)
      expect(pa.assignment_type).to eq('required')
    end

    it 'updates existing PositionAssignment' do
      existing_pa = create(:position_assignment,
        position: position,
        assignment: company_assignment,
        min_estimated_energy: 10,
        max_estimated_energy: 20,
        assignment_type: 'suggested'
      )
      
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            min_estimated_energy: '25',
            max_estimated_energy: '50',
            anticipated_energy_percentage: '35',
            assignment_type: 'required'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      
      existing_pa.reload
      expect(existing_pa.min_estimated_energy).to eq(25)
      expect(existing_pa.max_estimated_energy).to eq(50)
      expect(existing_pa.anticipated_energy_percentage).to eq(35)
      expect(existing_pa.assignment_type).to eq('required')
    end

    it 'destroys PositionAssignment when max_estimated_energy is 0' do
      existing_pa = create(:position_assignment,
        position: position,
        assignment: company_assignment,
        max_estimated_energy: 30
      )
      
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            max_estimated_energy: '0'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      expect(PositionAssignment.find_by(id: existing_pa.id)).to be_nil
    end

    it 'destroys PositionAssignment when not in params' do
      existing_pa1 = create(:position_assignment, position: position, assignment: company_assignment)
      existing_pa2 = create(:position_assignment, position: position, assignment: department_assignment)
      
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            max_estimated_energy: '50'
          }
        }
      }
      
      expect(PositionAssignment.find_by(id: existing_pa1.id)).to be_present
      expect(PositionAssignment.find_by(id: existing_pa2.id)).to be_nil
    end

    it 'handles multiple assignments in single request' do
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            min_estimated_energy: '10',
            max_estimated_energy: '30',
            anticipated_energy_percentage: '20',
            assignment_type: 'required'
          },
          department_assignment.id => {
            min_estimated_energy: '20',
            max_estimated_energy: '40',
            anticipated_energy_percentage: '30',
            assignment_type: 'suggested'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      
      pa1 = PositionAssignment.find_by(position: position, assignment: company_assignment)
      pa2 = PositionAssignment.find_by(position: position, assignment: department_assignment)
      
      expect(pa1).to be_present
      expect(pa2).to be_present
      expect(pa1.assignment_type).to eq('required')
      expect(pa2.assignment_type).to eq('suggested')
    end

    it 'validates min <= max' do
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            min_estimated_energy: '50',
            max_estimated_energy: '30',
            assignment_type: 'required'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      expect(flash[:alert]).to be_present
      expect(flash[:alert]).to include('minimum energy')
    end

    it 'requires update permission' do
      teammate.update(can_manage_employment: false)
      
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {}
      }
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end

    it 'handles nil values for optional fields' do
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            min_estimated_energy: '',
            max_estimated_energy: '50',
            anticipated_energy_percentage: '',
            assignment_type: 'required'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      
      pa = PositionAssignment.find_by(position: position, assignment: company_assignment)
      expect(pa.min_estimated_energy).to be_nil
      expect(pa.max_estimated_energy).to eq(50)
      expect(pa.anticipated_energy_percentage).to be_nil
    end
  end
end

