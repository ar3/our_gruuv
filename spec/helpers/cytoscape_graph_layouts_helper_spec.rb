# frozen_string_literal: true

require "rails_helper"

RSpec.describe CytoscapeGraphLayoutsHelper, type: :helper do
  describe "#cytoscape_supply_flow_graph_locals" do
    let(:organization) { create(:organization, :company) }
    let(:assignment) { create(:assignment, company: organization) }
    let(:elements) do
      [{ group: "nodes", data: { id: "a#{assignment.id}", label: assignment.title } }]
    end

    it "includes elements and root_node_ids for the partial" do
      allow(helper).to receive(:cytoscape_graph_layout_editable?).and_return(false)

      locals = helper.cytoscape_supply_flow_graph_locals(
        elements: elements,
        root_node_ids: ["a#{assignment.id}"],
        layoutable: assignment,
        graph_kind: "accountability_flow",
        organization: organization
      )

      expect(locals[:elements]).to eq(elements)
      expect(locals[:root_node_ids]).to eq(["a#{assignment.id}"])
      expect(locals).to have_key(:layout_url)
    end

    it "overlays matching saved positions onto elements for preset layouts" do
      allow(helper).to receive(:cytoscape_graph_layout_editable?).and_return(false)
      title_elements = [{ group: "nodes", data: { id: "a#{assignment.id}", label: "T" }, position: { x: 0, y: 0 } }]
      fingerprint = Assignments::SupplyGraphElements.cytoscape_node_fingerprint(title_elements)
      CytoscapeGraphLayout.create!(
        layoutable: organization,
        graph_kind: "title_paths",
        node_fingerprint: fingerprint,
        positions: { "a#{assignment.id}" => { "x" => 99.0, "y" => 88.0 } }
      )

      locals = helper.cytoscape_supply_flow_graph_locals(
        elements: title_elements,
        root_node_ids: ["a#{assignment.id}"],
        layoutable: organization,
        graph_kind: "title_paths",
        organization: organization
      )

      expect(locals[:elements].first[:position]).to eq(x: 99.0, y: 88.0)
      expect(locals[:layout_url]).to eq(organization_title_paths_cytoscape_graph_layout_path(organization))
    end
  end
end
