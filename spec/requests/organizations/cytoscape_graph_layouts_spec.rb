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

  describe "PATCH /organizations/:organization_id/full_network_cytoscape_graph_layout" do
    it "persists node positions for the organization full network graph" do
      supplier = create(:assignment, company: organization)
      consumer = create(:assignment, company: organization)
      create(:assignment_supply_relationship, supplier_assignment: supplier, consumer_assignment: consumer)

      patch organization_full_network_cytoscape_graph_layout_path(organization),
            params: {
              positions: {
                "a#{supplier.id}" => { x: 10, y: 20 },
                "a#{consumer.id}" => { x: 30, y: 40 }
              },
              node_fingerprint: "test-fingerprint"
            },
            as: :json

      expect(response).to have_http_status(:no_content)

      layout = CytoscapeGraphLayout.for_layoutable(organization, graph_kind: "full_network")
      expect(layout.positions.keys).to contain_exactly("a#{supplier.id}", "a#{consumer.id}")
    end
  end

  describe "PATCH /organizations/:organization_id/title_paths_cytoscape_graph_layout" do
    it "persists node positions for the organization title paths graph" do
      major = create(:position_major_level, major_level: 1, set_name: "TP-#{SecureRandom.hex(4)}")
      dest_major = create(:position_major_level, major_level: 2, set_name: "TP-#{SecureRandom.hex(4)}")
      from_title = create(:title, company: organization, position_major_level: major, external_title: "From")
      to_title = create(:title, company: organization, position_major_level: dest_major, external_title: "To")
      create(:title_path, from_title: from_title, to_title: to_title, path_type: "natural_progression")

      patch organization_title_paths_cytoscape_graph_layout_path(organization),
            params: {
              positions: {
                "title-#{from_title.id}" => { x: 10, y: 20 },
                "title-#{to_title.id}" => { x: 230, y: 40 }
              },
              node_fingerprint: "title-paths-fingerprint"
            },
            as: :json

      expect(response).to have_http_status(:no_content)

      layout = CytoscapeGraphLayout.for_layoutable(organization, graph_kind: "title_paths")
      expect(layout.positions.keys).to contain_exactly("title-#{from_title.id}", "title-#{to_title.id}")
      expect(layout.node_fingerprint).to eq("title-paths-fingerprint")
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

  describe "DELETE /organizations/:organization_id/title_paths_cytoscape_graph_layout" do
    it "removes the organization title-paths layout" do
      CytoscapeGraphLayout.create!(
        layoutable: organization,
        graph_kind: "title_paths",
        positions: { "title-1" => { "x" => 1, "y" => 2 } }
      )

      delete organization_title_paths_cytoscape_graph_layout_path(organization)

      expect(response).to have_http_status(:no_content)
      expect(CytoscapeGraphLayout.for_layoutable(organization, graph_kind: "title_paths")).to be_nil
    end
  end
end
