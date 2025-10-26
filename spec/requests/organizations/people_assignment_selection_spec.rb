require 'rails_helper'

RSpec.describe 'Organizations::People Assignment Selection', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let!(:position_type) { create(:position_type, organization: organization) }
  let!(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  
  let!(:manager_employment) { create(:employment_tenure, teammate: manager_teammate, position: position, started_at: 2.years.ago, ended_at: nil) }
  let!(:employment_tenure) { create(:employment_tenure, teammate: teammate, position: position, manager: manager, started_at: 1.year.ago, ended_at: nil) }
  
  let!(:required_assignment) { create(:assignment, company: organization, title: 'Required Assignment') }
  let!(:optional_assignment1) { create(:assignment, company: organization, title: 'Optional Assignment 1') }
  let!(:optional_assignment2) { create(:assignment, company: organization, title: 'Optional Assignment 2') }
  
  let!(:position_assignment) { create(:position_assignment, position: position, assignment: required_assignment) }

  before do
    # Setup authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(manager).to receive(:can_manage_employment?).with(organization).and_return(true)
    allow(manager).to receive(:can_manage_employment?).and_return(true)
    allow(manager).to receive(:in_managerial_hierarchy_of?).and_return(true)
  end

  describe 'GET #assignment_selection' do
    context 'when user is authorized' do
      it 'returns success' do
        get assignment_selection_organization_person_path(organization, person)
        
        if response.status == 302
          puts "Redirected to: #{response.location}"
          puts "Flash: #{flash.inspect}"
        end
        
        expect(response).to have_http_status(:success)
      end

      it 'loads all assignments for the organization' do
        get assignment_selection_organization_person_path(organization, person)
        expect(assigns(:assignments)).to include(required_assignment, optional_assignment1, optional_assignment2)
      end

      it 'identifies required assignments from position' do
        # Ensure the employment tenure uses the correct position
        employment_tenure.update!(position: position)
        
        get assignment_selection_organization_person_path(organization, person)
        
        expect(assigns(:required_assignment_ids)).to include(required_assignment.id)
        expect(assigns(:required_assignment_ids)).not_to include(optional_assignment1.id)
      end

      it 'identifies assignments with active tenures' do
        create(:assignment_tenure, teammate: teammate, assignment: optional_assignment1, started_at: 1.month.ago, ended_at: nil)
        
        get assignment_selection_organization_person_path(organization, person)
        expect(assigns(:assigned_assignment_ids)).to include(optional_assignment1.id)
        expect(assigns(:assigned_assignment_ids)).not_to include(optional_assignment2.id)
      end

      it 'loads the current employment tenure' do
        get assignment_selection_organization_person_path(organization, person)
        expect(assigns(:current_employment)).to eq(employment_tenure)
      end
    end

    context 'when user is not authorized' do
      let(:other_person) { create(:person) }
      
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(other_person)
        allow(other_person).to receive(:can_manage_employment?).with(organization).and_return(false)
        allow(other_person).to receive(:can_manage_employment?).and_return(false)
        allow(other_person).to receive(:in_managerial_hierarchy_of?).and_return(false)
      end

      it 'redirects with authorization error' do
        get assignment_selection_organization_person_path(organization, person)
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to match(/permission/)
      end
    end

    context 'when person has no employment' do
      before do
        employment_tenure.destroy
      end

      it 'returns success but with no required assignments' do
        get assignment_selection_organization_person_path(organization, person)
        expect(response).to have_http_status(:success)
        expect(assigns(:required_assignment_ids)).to be_empty
      end
    end
  end

  describe 'POST #update_assignments' do
    context 'when user is authorized' do
      it 'creates new assignment tenures for checked assignments' do
        expect {
          post update_assignments_organization_person_path(organization, person), params: {
            assignment_ids: [optional_assignment1.id.to_s, optional_assignment2.id.to_s]
          }
        }.to change(AssignmentTenure, :count).by(2)
        
        tenure1 = AssignmentTenure.find_by(teammate: teammate, assignment: optional_assignment1)
        tenure2 = AssignmentTenure.find_by(teammate: teammate, assignment: optional_assignment2)
        
        expect(tenure1).to be_present
        expect(tenure1.started_at).to eq(Date.current)
        expect(tenure1.anticipated_energy_percentage).to eq(0)
        expect(tenure1.ended_at).to be_nil
        
        expect(tenure2).to be_present
        expect(tenure2.started_at).to eq(Date.current)
        expect(tenure2.anticipated_energy_percentage).to eq(0)
        expect(tenure2.ended_at).to be_nil
      end

      it 'does not create duplicate tenures for already assigned assignments' do
        existing_tenure = create(:assignment_tenure, teammate: teammate, assignment: optional_assignment1, started_at: 1.month.ago, ended_at: nil)
        
        expect {
          post update_assignments_organization_person_path(organization, person), params: {
            assignment_ids: [optional_assignment1.id.to_s]
          }
        }.not_to change(AssignmentTenure, :count)
        
        expect(existing_tenure.reload.ended_at).to be_nil
      end

      it 'redirects to check-ins page after save' do
        post update_assignments_organization_person_path(organization, person), params: {
          assignment_ids: [optional_assignment1.id.to_s]
        }
        
        expect(response).to redirect_to(organization_person_check_ins_path(organization, person))
      end

      it 'shows success message' do
        post update_assignments_organization_person_path(organization, person), params: {
          assignment_ids: [optional_assignment1.id.to_s]
        }
        
        expect(flash[:notice]).to be_present
      end

      it 'handles empty assignment selection' do
        expect {
          post update_assignments_organization_person_path(organization, person), params: {
            assignment_ids: []
          }
        }.not_to change(AssignmentTenure, :count)
        
        expect(response).to redirect_to(organization_person_check_ins_path(organization, person))
      end

      it 'handles nil assignment_ids parameter' do
        expect {
          post update_assignments_organization_person_path(organization, person)
        }.not_to change(AssignmentTenure, :count)
        
        expect(response).to redirect_to(organization_person_check_ins_path(organization, person))
      end
    end

    context 'when user is not authorized' do
      let(:other_person) { create(:person) }
      
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(other_person)
        allow(other_person).to receive(:can_manage_employment?).with(organization).and_return(false)
        allow(other_person).to receive(:can_manage_employment?).and_return(false)
        allow(other_person).to receive(:in_managerial_hierarchy_of?).and_return(false)
      end

      it 'redirects with authorization error' do
        post update_assignments_organization_person_path(organization, person), params: {
          assignment_ids: [optional_assignment1.id.to_s]
        }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to match(/permission/)
      end
    end
  end
end

