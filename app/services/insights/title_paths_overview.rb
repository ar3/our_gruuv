# frozen_string_literal: true

module Insights
  # Org-wide (optionally department-filtered) title-path graph for Position · Insights.
  class TitlePathsOverview
    PATH_TYPE_COLORS = {
      "natural_progression" => "#0d6efd",
      "parallel_progression" => "#6f42c1",
      "switch_to_people_management" => "#198754",
      "switch_to_individual_contribution" => "#fd7e14",
      "switch_to_project_technical_leadership" => "#20c997"
    }.freeze

    HIGHLIGHT_PRIMARY = "suggested"
    HIGHLIGHT_EXTERNAL = "external"

    COLUMN_WIDTH = 220
    ROW_HEIGHT = 72
    MIN_MAJOR_LEVEL = 1
    MAX_MAJOR_LEVEL = 10

    Result = Struct.new(
      :connected_count,
      :unconnected_count,
      :elements,
      :root_node_ids,
      :g6_graph_data,
      :selected_department,
      :department_options,
      :show_graph,
      keyword_init: true
    )

    def self.call(organization:, department_id: nil)
      new(organization: organization, department_id: department_id).call
    end

    def initialize(organization:, department_id: nil)
      @organization = organization
      @department_id = department_id.presence
    end

    def call
      titles = load_titles
      selected_department = find_selected_department
      primary_titles = primary_titles_for(titles, selected_department)
      primary_ids = primary_titles.map(&:id).to_set

      connected_count = primary_titles.count { |title| connected?(title) }
      unconnected_count = primary_titles.size - connected_count

      paths = paths_touching(primary_ids)
      graph_titles = graph_titles_for(titles, paths, primary_ids)
      elements = build_elements(graph_titles, primary_ids, paths)
      roots = root_node_ids_for(graph_titles, paths, primary_ids)

      Result.new(
        connected_count: connected_count,
        unconnected_count: unconnected_count,
        elements: elements,
        root_node_ids: roots,
        g6_graph_data: g6_graph_data_for(elements),
        selected_department: selected_department,
        department_options: department_options,
        show_graph: paths.any?
      )
    end

    private

    attr_reader :organization, :department_id

    def load_titles
      organization.titles
                  .unarchived
                  .includes(:department, :position_major_level, :inbound_title_paths, :outbound_title_paths)
                  .to_a
    end

    def find_selected_department
      return nil if department_id.blank?

      Department.for_company(organization).active.find_by(id: department_id)
    end

    def primary_titles_for(titles, selected_department)
      return titles if selected_department.blank?

      dept_ids = selected_department.self_and_descendants.map(&:id).to_set
      titles.select { |title| title.department_id.present? && dept_ids.include?(title.department_id) }
    end

    # Spotlight / copy: end-cap or any path edge counts as connected.
    def connected?(title)
      title.end_cap? || title.inbound_title_paths.any? || title.outbound_title_paths.any?
    end

    def paths_touching(primary_ids)
      return [] if primary_ids.empty?

      TitlePath
        .where(from_title_id: primary_ids)
        .or(TitlePath.where(to_title_id: primary_ids))
        .includes(:from_title, :to_title)
        .to_a
    end

    # Graph nodes: only titles that participate in at least one path (plus external neighbors).
    def graph_titles_for(titles, paths, primary_ids)
      return [] if paths.empty?

      title_ids = Set.new
      paths.each do |path|
        title_ids << path.from_title_id
        title_ids << path.to_title_id
      end

      by_id = titles.index_by(&:id)
      title_ids.filter_map { |id| by_id[id] }
    end

    def build_elements(graph_titles, primary_ids, paths)
      nodes = {}
      graph_titles.each do |title|
        highlight = primary_ids.include?(title.id) ? HIGHLIGHT_PRIMARY : HIGHLIGHT_EXTERNAL
        add_node!(nodes, title, highlight)
      end
      apply_major_level_positions!(nodes, graph_titles)

      edges = paths.filter_map do |path|
        next unless nodes.key?(node_id(path.from_title_id)) && nodes.key?(node_id(path.to_title_id))

        edge_element(path)
      end

      nodes.values + edges
    end

    def apply_major_level_positions!(nodes, graph_titles)
      by_level = graph_titles.group_by { |title| major_level_for(title) }
      by_level.keys.sort.each do |level|
        titles_at_level = by_level[level].sort_by { |title| title.external_title.to_s.downcase }
        titles_at_level.each_with_index do |title, index|
          node = nodes[node_id(title.id)]
          next unless node

          node[:position] = {
            x: (level - MIN_MAJOR_LEVEL) * COLUMN_WIDTH,
            y: index * ROW_HEIGHT
          }
          node[:data][:majorLevel] = level
        end
      end
    end

    def major_level_for(title)
      level = title.position_major_level&.major_level.to_i
      level = MIN_MAJOR_LEVEL if level < MIN_MAJOR_LEVEL
      level = MAX_MAJOR_LEVEL if level > MAX_MAJOR_LEVEL
      level
    end

    def root_node_ids_for(graph_titles, paths, primary_ids)
      primary_graph = graph_titles.select { |title| primary_ids.include?(title.id) }
      targets_in_graph = paths.each_with_object(Set.new) do |path, set|
        set << path.to_title_id if primary_ids.include?(path.to_title_id)
      end

      roots = primary_graph.reject { |title| targets_in_graph.include?(title.id) }.map { |title| node_id(title.id) }
      roots = primary_graph.first(1).map { |title| node_id(title.id) } if roots.empty? && primary_graph.any?
      roots
    end

    def add_node!(nodes, title_record, highlight)
      id = node_id(title_record.id)
      return if nodes.key?(id)

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

    def edge_element(path)
      color = PATH_TYPE_COLORS.fetch(path.path_type, "#6c757d")
      {
        group: "edges",
        data: {
          id: "tp#{path.id}",
          source: node_id(path.from_title_id),
          target: node_id(path.to_title_id),
          label: path.path_type_label,
          pathType: path.path_type,
          lineColor: color
        }
      }
    end

    def g6_graph_data_for(elements)
      nodes = elements.select { |element| element[:group] == "nodes" }.map do |element|
        position = element[:position] || { x: 0, y: 0 }
        label = element.dig(:data, :label).to_s
        highlight = element.dig(:data, :highlightTier)
        {
          id: element.dig(:data, :id),
          data: {
            label: label,
            url: element.dig(:data, :url),
            highlightTier: highlight,
            majorLevel: element.dig(:data, :majorLevel)
          },
          style: {
            x: position[:x],
            y: position[:y],
            label: true,
            labelText: label,
            labelPlacement: "center",
            labelWordWrap: true,
            labelMaxWidth: "90%",
            labelFontSize: 11,
            labelFill: "#212529",
            fill: (highlight == HIGHLIGHT_EXTERNAL ? "#f1f3f5" : "#e7f1ff"),
            stroke: (highlight == HIGHLIGHT_EXTERNAL ? "#ced4da" : "#6ea8fe")
          }
        }
      end

      edges = elements.select { |element| element[:group] == "edges" }.map do |element|
        {
          id: element.dig(:data, :id),
          source: element.dig(:data, :source),
          target: element.dig(:data, :target),
          data: {
            label: element.dig(:data, :label),
            pathType: element.dig(:data, :pathType),
            lineColor: element.dig(:data, :lineColor)
          },
          style: {
            stroke: element.dig(:data, :lineColor) || "#6c757d"
          }
        }
      end

      { nodes: nodes, edges: edges }
    end

    def node_id(title_id)
      "title-#{title_id}"
    end

    def department_options
      Department.for_company(organization).active.sort_by { |dept| dept.display_name.to_s.downcase }.map do |dept|
        [dept.display_name, dept.id]
      end
    end
  end
end
