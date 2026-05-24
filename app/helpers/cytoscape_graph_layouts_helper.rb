# frozen_string_literal: true

module CytoscapeGraphLayoutsHelper
  def cytoscape_supply_flow_graph_locals(elements:, root_node_ids:, layoutable:, graph_kind:, organization:, **options)
    layout = CytoscapeGraphLayout.for_layoutable(layoutable, graph_kind: graph_kind)
    fingerprint = Assignments::SupplyGraphElements.cytoscape_node_fingerprint(elements)

    {
      elements: elements,
      root_node_ids: root_node_ids,
      saved_positions: layout&.positions || {},
      node_fingerprint: fingerprint,
      stored_node_fingerprint: layout&.node_fingerprint.to_s,
      layout_url: cytoscape_graph_layout_url_for(organization, layoutable, graph_kind),
      can_edit_layout: cytoscape_graph_layout_editable?(layoutable)
    }.merge(options)
  end

  def cytoscape_graph_layout_url_for(organization, layoutable, graph_kind)
    case graph_kind
    when "full_network"
      organization_full_network_cytoscape_graph_layout_path(organization)
    when "accountability_flow"
      organization_assignment_cytoscape_graph_layout_path(organization, layoutable)
    when "position_reliance"
      organization_position_cytoscape_graph_layout_path(organization, layoutable)
    else
      raise ArgumentError, "unknown graph_kind: #{graph_kind}"
    end
  end

  def cytoscape_graph_layout_editable?(layoutable)
    policy(layoutable).update_cytoscape_graph_layout?
  rescue Pundit::NotDefinedError
    false
  end
end
