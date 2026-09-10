# frozen_string_literal: true

module Titles
  # One-hop inbound/outbound title-path neighborhood for Cytoscape on Title show.
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

      add_node!(nodes, title, HIGHLIGHT_CURRENT)

      outbound_paths.each do |path|
        add_node!(nodes, path.to_title, HIGHLIGHT_OUTBOUND)
        edges << edge_element(path, source: title, target: path.to_title)
      end

      inbound_paths.each do |path|
        add_node!(nodes, path.from_title, HIGHLIGHT_INBOUND)
        edges << edge_element(path, source: path.from_title, target: title)
      end

      nodes.values + edges
    end

    def root_node_ids
      return [] unless show_graph?

      # Prefer inbound sources as roots so dagre flows toward the current title and outbound.
      roots = inbound_paths.map { |path| node_id(path.from_title_id) }
      roots = [node_id(title.id)] if roots.empty?
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

    def add_node!(nodes, title_record, highlight)
      id = node_id(title_record.id)
      existing = nodes[id]
      if existing
        # Keep current-title highlight if the same node appears in both roles.
        return if existing.dig(:data, :highlightTier) == HIGHLIGHT_CURRENT

        existing[:data][:highlightTier] = highlight if highlight == HIGHLIGHT_CURRENT
        return
      end

      nodes[id] = {
        group: "nodes",
        data: {
          id: id,
          label: title_record.title_including_level.to_s.truncate(60),
          url: Rails.application.routes.url_helpers.organization_title_path(organization, title_record),
          highlightTier: highlight
        }
      }
    end

    def edge_element(path, source:, target:)
      {
        group: "edges",
        data: {
          id: "tp#{path.id}",
          source: node_id(source.id),
          target: node_id(target.id),
          label: path.path_type_label,
          pathType: path.path_type,
          lineColor: Insights::TitlePathsOverview::PATH_TYPE_COLORS.fetch(path.path_type, "#6c757d")
        }
      }
    end

    def node_id(title_id)
      "title-#{title_id}"
    end
  end
end
