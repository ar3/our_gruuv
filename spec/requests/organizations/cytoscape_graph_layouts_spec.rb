# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::CytoscapeGraphLayouts", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) do
    create(:teammate, :unassigned_employee, person: person, organization: organization, can_manage_maap: true)
  end

  before { sign_in_as_teammate_for_request(person, organization) }

  describe "PATCH /organizations/:organization_id/assignments/:assignment_id/cytoscape_graph_layout" do
    let(:assignment) { create(:assignment, company: organization) }
    let(:consumer) { create(:assignment, company: organization) }

    before do
      create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: consumer)
    end

    it "persists node positions for the assignment graph" do
      patch organization_assignment_cytoscape_graph_layout_path(organization, assignment),
            params: {
              positions: { "a#{assignment.id}" => { x: 120, y: 240 } },
              node_fingerprint: "test-fingerprint"
            },
            as: :json

      expect(response).to have_http_status(:no_content)

      layout = CytoscapeGraphLayout.for_layoutable(assignment, graph_kind: "accountability_flow")
      expect(layout.positions).to eq("a#{assignment.id}" => { "x" => 120.0, "y" => 240.0 })
      expect(layout.node_fingerprint).to eq("test-fingerprint")
    end
  end

  describe "DELETE /organizations/:organization_id/full_network_cytoscape_graph_layout" do
    it "removes the organization full-network layout" do
      CytoscapeGraphLayout.create!(
        layoutable: organization,
        graph_kind: "full_network",
        positions: { "a1" => { "x" => 1, "y" => 2 } }
      )

      delete organization_full_network_cytoscape_graph_layout_path(organization)

      expect(response).to have_http_status(:no_content)
      expect(CytoscapeGraphLayout.for_layoutable(organization, graph_kind: "full_network")).to be_nil
    end
  end
end
