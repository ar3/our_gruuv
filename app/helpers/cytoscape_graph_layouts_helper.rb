# frozen_string_literal: true

module CytoscapeGraphLayoutsHelper
  def cytoscape_supply_flow_graph_locals(elements:, root_node_ids:, layoutable:, graph_kind:, organization:, **options)
    layout = CytoscapeGraphLayout.for_layoutable(layoutable, graph_kind: graph_kind)
    fingerprint = Assignments::SupplyGraphElements.cytoscape_node_fingerprint(elements)
    positioned_elements = apply_saved_layout_positions(elements, layout, fingerprint)

    {
      elements: positioned_elements,
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
    when "title_paths"
      organization_title_paths_cytoscape_graph_layout_path(organization)
    else
      raise ArgumentError, "unknown graph_kind: #{graph_kind}"
    end
  end

  def cytoscape_graph_layout_editable?(layoutable)
    policy(layoutable).update_cytoscape_graph_layout?
  rescue Pundit::NotDefinedError
    false
  end

  # Preset-layout graphs (e.g. title paths) read coordinates from elements, so a
  # matching saved layout must be merged server-side before render.
  def apply_saved_layout_positions(elements, layout, fingerprint)
    return elements if layout.blank? || layout.positions.blank?
    return elements if layout.node_fingerprint.to_s != fingerprint.to_s

    elements.map do |element|
      group = element[:group] || element["group"]
      next element unless group == "nodes"

      data = element[:data] || element["data"] || {}
      id = data[:id] || data["id"]
      coords = layout.positions[id.to_s] || layout.positions[id]
      next element unless coords

      element.merge(position: { x: coords["x"].to_f, y: coords["y"].to_f })
    end
  end
end
