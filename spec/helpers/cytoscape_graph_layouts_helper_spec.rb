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
  end
end
