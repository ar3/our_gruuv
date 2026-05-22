# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::AssignmentFlows', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, :unassigned_employee, person: person, organization: organization) }
  let(:assignment_flow) do
    create(:assignment_flow, company: organization, created_by: teammate, updated_by: teammate)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/assignment_flows' do
    it 'returns success and lists assignment flows' do
      assignment_flow
      get organization_assignment_flows_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Assignment Flows')
      expect(response.body).to include('Full network graph')
      expect(response.body).to include(assignment_flow.name)
    end
  end

  describe 'GET /organizations/:organization_id/assignment_flows/full_network_graph' do
    it 'returns success and shows full network graph page with visualization tabs' do
      supplier = create(:assignment, company: organization, title: 'Root Supplier')
      consumer = create(:assignment, company: organization, title: 'Downstream Consumer')
      create(:assignment_supply_relationship, supplier_assignment: supplier, consumer_assignment: consumer)

      get full_network_graph_organization_assignment_flows_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Full network graph')
      expect(response.body).to include('Automatic flow')
      expect(response.body).to include('full-network-mermaid-tab')
      expect(response.body).to match(/full-network-mermaid-tab[^<]*active/)
      expect(response.body).to include('Cytoscape')
      expect(response.body).to include('Highcharts – Sankey')
      expect(response.body).to include('Highcharts – Network')
      expect(response.body).to include('full-network-highcharts-sankey-pane')
      expect(response.body).to include('full-network-highcharts-network-pane')
      expect(response.body).to include('full-network-g6-pane')
      expect(response.body).to include('G6')
      expect(response.body).to include('g6.min.js')
      expect(response.body).to include('vis.js')
      expect(response.body).to include('Mermaid')
      expect(response.body).to include('mermaid.min.js')
      expect(response.body).to include('assignment-flow-mermaid-source-value')
      expect(response.body).to include('assignment-full-network-graph-g6-graph-data-json-value')
      expect(response.body).to include('flowchart TB')
      expect(response.body).to include('networkgraph.js')
      expect(response.body).to include('assignment-full-network-graph')
    end

    it 'shows assignments that have supply relationships' do
      supplier = create(:assignment, company: organization, title: 'Supplier Assignment')
      consumer = create(:assignment, company: organization, title: 'Consumer Assignment')
      create(:assignment_supply_relationship, supplier_assignment: supplier, consumer_assignment: consumer)
      get full_network_graph_organization_assignment_flows_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Supplier Assignment')
      expect(response.body).to include('Consumer Assignment')
      expect(response.body).to include('assignment-accountability-flow')
    end
  end

  describe 'GET /organizations/:organization_id/assignment_flows/:id' do
    it 'returns success and includes Group column header when flow has memberships' do
      assignment = create(:assignment, company: organization)
      create(:assignment_flow_membership, assignment_flow: assignment_flow, assignment: assignment, placement: 0, added_by: teammate)
      get organization_assignment_flow_path(organization, assignment_flow)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(assignment_flow.name)
      expect(response.body).to include('Group')
    end
  end

  describe 'GET /organizations/:organization_id/assignment_flows/new' do
    it 'returns success' do
      get new_organization_assignment_flow_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('New Assignment Flow')
    end
  end

  describe 'POST /organizations/:organization_id/assignment_flows' do
    it 'creates an assignment flow and redirects to edit' do
      expect {
        post organization_assignment_flows_path(organization), params: { assignment_flow: { name: 'Onboarding Flow' } }
      }.to change(AssignmentFlow, :count).by(1)
      expect(AssignmentFlow.last.name).to eq('Onboarding Flow')
      expect(response).to redirect_to(edit_organization_assignment_flow_path(organization, AssignmentFlow.last))
    end
  end

  describe 'GET /organizations/:organization_id/assignment_flows/:id/edit' do
    it 'returns success and includes Group name column' do
      create(:assignment, company: organization) # so assignments table renders
      get edit_organization_assignment_flow_path(organization, assignment_flow)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Edit')
      expect(response.body).to include(assignment_flow.name)
      expect(response.body).to include('Group name')
    end
  end

  describe 'PATCH /organizations/:organization_id/assignment_flows/:id' do
    let(:assignment) { create(:assignment, company: organization) }

    it 'updates memberships and redirects to show' do
      patch organization_assignment_flow_path(organization, assignment_flow), params: {
        assignment_flow: { name: assignment_flow.name },
        placements: { assignment.id.to_s => '1' }
      }
      expect(response).to redirect_to(organization_assignment_flow_path(organization, assignment_flow))
      expect(assignment_flow.assignment_flow_memberships.reload.count).to eq(1)
      expect(assignment_flow.assignment_flow_memberships.first.placement).to eq(1)
    end

    it 'saves group_name when group_names are submitted' do
      patch organization_assignment_flow_path(organization, assignment_flow), params: {
        assignment_flow: { name: assignment_flow.name },
        placements: { assignment.id.to_s => '1' },
        group_names: { assignment.id.to_s => 'Onboarding' }
      }
      expect(response).to redirect_to(organization_assignment_flow_path(organization, assignment_flow))
      expect(assignment_flow.assignment_flow_memberships.reload.first.group_name).to eq('Onboarding')
    end
  end

  describe 'DELETE /organizations/:organization_id/assignment_flows/:id' do
    it 'destroys the flow and redirects to index' do
      assignment_flow
      expect {
        delete organization_assignment_flow_path(organization, assignment_flow)
      }.to change(AssignmentFlow, :count).by(-1)
      expect(response).to redirect_to(organization_assignment_flows_path(organization))
    end
  end
end
