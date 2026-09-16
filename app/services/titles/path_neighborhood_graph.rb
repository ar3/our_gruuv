# frozen_string_literal: true

module Titles
  # One-hop inbound/outbound title-path neighborhood for Cytoscape on Title/Position show.
  # Uses the same major-level column layout rules as Insights::TitlePathsOverview.
  class PathNeighborhoodGraph
    HIGHLIGHT_CURRENT = "required"
    HIGHLIGHT_OUTBOUND = "suggested"
    HIGHLIGHT_INBOUND = "external"

    def initialize(title:, organization:)
      @title = title
      @organization = organization
    end

    def show_graph?
      inbound_paths.any? || outbound_paths.any?
    end

    def elements
      return [] unless show_graph?

      nodes = {}
      edges = []
      graph_titles = []

      add_node!(nodes, graph_titles, title, HIGHLIGHT_CURRENT)

      outbound_paths.each do |path|
        add_node!(nodes, graph_titles, path.to_title, HIGHLIGHT_OUTBOUND)
        edges << PathGraphLayout.edge_element(path)
      end

      inbound_paths.each do |path|
        add_node!(nodes, graph_titles, path.from_title, HIGHLIGHT_INBOUND)
        edges << PathGraphLayout.edge_element(path)
      end

      PathGraphLayout.apply_major_level_positions!(
        nodes: nodes,
        titles: graph_titles,
        paths: inbound_paths + outbound_paths
      )

      nodes.values + edges
    end

    def root_node_ids
      return [] unless show_graph?

      # Prefer inbound sources as roots (used when layout falls back to dagre).
      roots = inbound_paths.map { |path| PathGraphLayout.node_id(path.from_title_id) }
      roots = [PathGraphLayout.node_id(title.id)] if roots.empty?
      roots.uniq
    end

    private

    attr_reader :title, :organization

    def inbound_paths
      @inbound_paths ||= title.inbound_title_paths.includes(from_title: :position_major_level).to_a
    end

    def outbound_paths
      @outbound_paths ||= title.outbound_title_paths.includes(to_title: :position_major_level).to_a
    end

    def add_node!(nodes, graph_titles, title_record, highlight)
      id = PathGraphLayout.node_id(title_record.id)
      existing = nodes[id]
      if existing
        # Keep current-title highlight if the same node appears in both roles.
        return if existing.dig(:data, :highlightTier) == HIGHLIGHT_CURRENT

        existing[:data][:highlightTier] = highlight if highlight == HIGHLIGHT_CURRENT
        return
      end

      nodes[id] = PathGraphLayout.node_element(
        organization: organization,
        title: title_record,
        highlight: highlight
      )
      graph_titles << title_record
    end
  end
end
