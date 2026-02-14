# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::AssignmentFlowsController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    tm = person.company_teammates.find_or_create_by!(organization: organization) do |t|
      t.first_employed_at ||= 1.month.ago
      t.last_terminated_at = nil
    end
    tm.update!(first_employed_at: 1.month.ago, last_terminated_at: nil) unless tm.employed?
    tm
  end
  let(:assignment_flow) do
    create(:assignment_flow, company: organization, created_by: teammate, updated_by: teammate)
  end
  let(:assignment) { create(:assignment, company: organization) }

  before do
    teammate
    sign_in_as_teammate(person, organization)
    allow(controller).to receive(:current_company_teammate).and_return(teammate)
  end

  describe 'GET #index' do
    it 'returns success and assigns assignment_flows' do
      assignment_flow
      get :index, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
      expect(assigns(:assignment_flows)).to include(assignment_flow)
    end
  end

  describe 'GET #show' do
    it 'returns success and assigns group_name_row_attrs for table rowspan' do
      get :show, params: { organization_id: organization.id, id: assignment_flow.id }
      expect(response).to have_http_status(:success)
      expect(assigns(:assignment_flow)).to eq(assignment_flow)
      expect(assigns(:group_name_row_attrs)).to eq([])
    end

    it 'builds group_name_row_attrs with rowspan for adjacent same group_name' do
      create(:assignment_flow_membership, assignment_flow: assignment_flow, assignment: assignment, placement: 0, added_by: teammate, group_name: 'Group A')
      other = create(:assignment, company: organization, title: 'Other')
      create(:assignment_flow_membership, assignment_flow: assignment_flow, assignment: other, placement: 1, added_by: teammate, group_name: 'Group A')
      get :show, params: { organization_id: organization.id, id: assignment_flow.id }
      expect(response).to have_http_status(:success)
      attrs = assigns(:group_name_row_attrs)
      expect(attrs.size).to eq(2)
      expect(attrs[0][:first_of_run]).to be true
      expect(attrs[0][:rowspan]).to eq(2)
      expect(attrs[0][:group_name]).to eq('Group A')
      expect(attrs[1][:first_of_run]).to be false
    end
  end

  describe 'GET #new' do
    it 'returns success and assigns new assignment_flow' do
      get :new, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
      expect(assigns(:assignment_flow)).to be_a_new(AssignmentFlow)
      expect(assigns(:assignment_flow).company).to eq(organization.root_company || organization)
    end
  end

  describe 'POST #create' do
    it 'creates an assignment flow and redirects to edit' do
      expect {
        post :create, params: { organization_id: organization.id, assignment_flow: { name: 'New Flow' } }
      }.to change(AssignmentFlow, :count).by(1)
      flow = AssignmentFlow.last
      expect(flow.name).to eq('New Flow')
      expect(flow.created_by).to eq(teammate)
      expect(flow.updated_by).to eq(teammate)
      expect(response).to redirect_to(edit_organization_assignment_flow_path(organization, flow))
    end

    it 're-renders new on validation error' do
      post :create, params: { organization_id: organization.id, assignment_flow: { name: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
    end
  end

  describe 'GET #edit' do
    it 'returns success and assigns assignments grouped by department with group names' do
      assignment
      get :edit, params: { organization_id: organization.id, id: assignment_flow.id }
      expect(response).to have_http_status(:success)
      expect(assigns(:assignment_flow)).to eq(assignment_flow)
      expect(assigns(:assignments_by_department)).to be_a(Hash)
      expect(assigns(:group_name_by_assignment_id)).to be_a(Hash)
      all_assignments = assigns(:assignments_by_department).values.flatten
      expect(all_assignments).to include(assignment)
    end
  end

  describe 'PATCH #update' do
    it 'updates memberships and redirects to show' do
      create(:assignment_flow_membership, assignment_flow: assignment_flow, assignment: assignment, placement: 1, added_by: teammate)
      patch :update, params: {
        organization_id: organization.id,
        id: assignment_flow.id,
        assignment_flow: { name: assignment_flow.name },
        placements: { assignment.id.to_s => '2' }
      }
      expect(response).to redirect_to(organization_assignment_flow_path(organization, assignment_flow))
      membership = assignment_flow.assignment_flow_memberships.reload.find_by(assignment: assignment)
      expect(membership.placement).to eq(2)
    end

    it 'saves group_name when group_names params are provided' do
      patch :update, params: {
        organization_id: organization.id,
        id: assignment_flow.id,
        assignment_flow: { name: assignment_flow.name },
        placements: { assignment.id.to_s => '1' },
        group_names: { assignment.id.to_s => 'Phase 1' }
      }
      expect(response).to redirect_to(organization_assignment_flow_path(organization, assignment_flow))
      membership = assignment_flow.assignment_flow_memberships.reload.find_by(assignment: assignment)
      expect(membership.group_name).to eq('Phase 1')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the assignment flow and redirects to index' do
      assignment_flow
      expect {
        delete :destroy, params: { organization_id: organization.id, id: assignment_flow.id }
      }.to change(AssignmentFlow, :count).by(-1)
      expect(response).to redirect_to(organization_assignment_flows_path(organization))
    end
  end
end
