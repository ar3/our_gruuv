# frozen_string_literal: true

module Titles
  # Shared title-path Cytoscape element helpers and major-level column layout.
  # Used by Insights::TitlePathsOverview and Titles::PathNeighborhoodGraph so
  # layout improvements apply everywhere we render title-path graphs.
  module PathGraphLayout
    PATH_TYPE_COLORS = {
      "natural_progression" => "#0d6efd",
      "parallel_progression" => "#6f42c1",
      "switch_to_people_management" => "#198754",
      "switch_to_individual_contribution" => "#fd7e14",
      "switch_to_project_technical_leadership" => "#20c997"
    }.freeze

    COLUMN_WIDTH = 220
    ROW_HEIGHT = 72
    MIN_MAJOR_LEVEL = 1
    MAX_MAJOR_LEVEL = 10

    module_function

    def node_id(title_id)
      "title-#{title_id}"
    end

    def node_element(organization:, title:, highlight:)
      {
        group: "nodes",
        data: {
          id: node_id(title.id),
          label: title.title_including_level.to_s.truncate(60),
          url: Rails.application.routes.url_helpers.organization_title_path(organization, title),
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

    # Keep major levels as fixed X columns; order Y within each column with a
    # barycenter heuristic so connected titles line up and edge crossings drop.
    def apply_major_level_positions!(nodes:, titles:, paths:)
      by_level = titles.group_by { |title| major_level_for(title) }
      levels = by_level.keys.sort
      order_by_level = levels.index_with do |level|
        by_level[level].sort_by { |title| title.external_title.to_s.downcase }
      end
      neighbor_ids = undirected_neighbor_ids(paths)

      8.times do
        levels.each do |level|
          order_by_level[level] = barycenter_order(
            titles: order_by_level[level],
            order_by_level: order_by_level,
            neighbor_ids: neighbor_ids,
            exclude_level: level
          )
        end
      end

      levels.each do |level|
        order_by_level[level].each_with_index do |title, index|
          node = nodes[node_id(title.id)]
          next unless node

          node[:position] = {
            x: (level - MIN_MAJOR_LEVEL) * COLUMN_WIDTH,
            y: index * ROW_HEIGHT
          }
          node[:data][:majorLevel] = level
        end
      end

      nodes
    end

    def major_level_for(title)
      level = title.position_major_level&.major_level.to_i
      level = MIN_MAJOR_LEVEL if level < MIN_MAJOR_LEVEL
      level = MAX_MAJOR_LEVEL if level > MAX_MAJOR_LEVEL
      level
    end

    def undirected_neighbor_ids(paths)
      neighbors = Hash.new { |hash, key| hash[key] = [] }
      paths.each do |path|
        neighbors[path.from_title_id] << path.to_title_id
        neighbors[path.to_title_id] << path.from_title_id
      end
      neighbors
    end

    def barycenter_order(titles:, order_by_level:, neighbor_ids:, exclude_level:)
      reference_index = {}
      order_by_level.each do |level, level_titles|
        next if level == exclude_level

        level_titles.each_with_index do |title, index|
          reference_index[title.id] = index
        end
      end

      titles.sort_by.with_index do |title, original_index|
        neighbor_positions = neighbor_ids[title.id].filter_map { |id| reference_index[id] }
        average = if neighbor_positions.any?
                    neighbor_positions.sum.to_f / neighbor_positions.size
                  else
                    Float::INFINITY
                  end
        [average, original_index, title.external_title.to_s.downcase]
      end
    end
  end
end
