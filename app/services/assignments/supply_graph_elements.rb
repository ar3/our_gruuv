# frozen_string_literal: true

module Assignments
  # Shared node/edge payloads for assignment supply relationship visualizations.
  module SupplyGraphElements
    module_function

    def cytoscape_elements(assignments, relationships, organization:, current_assignment_id: nil)
      nodes = assignments.map do |assignment|
        {
          group: 'nodes',
          data: {
            id: cytoscape_node_id(assignment.id),
            label: assignment.title.to_s.truncate(60),
            url: organization_assignment_path(organization, assignment),
            isCurrent: current_assignment_id.present? && assignment.id == current_assignment_id
          }
        }
      end

      edges = relationships.map do |relationship|
        {
          group: 'edges',
          data: {
            id: "e#{relationship.id}",
            source: cytoscape_node_id(relationship.supplier_assignment_id),
            target: cytoscape_node_id(relationship.consumer_assignment_id)
          }
        }
      end

      nodes + edges
    end

    def cytoscape_root_node_ids(relationships)
      consumer_ids = relationships.map(&:consumer_assignment_id).to_set
      supplier_ids = relationships.map(&:supplier_assignment_id).to_set
      roots = supplier_ids - consumer_ids
      roots = supplier_ids if roots.empty?
      roots.map { |id| cytoscape_node_id(id) }
    end

    def highcharts_network_graph_data(assignments, relationships, organization:)
      assignment_ids = assignments.map(&:id).to_set
      nodes = assignments.map do |assignment|
        {
          id: assignment.id.to_s,
          name: assignment.title.to_s.truncate(60),
          url: organization_assignment_path(organization, assignment)
        }
      end

      links = relationships.filter_map do |relationship|
        supplier_id = relationship.supplier_assignment_id
        consumer_id = relationship.consumer_assignment_id
        next unless assignment_ids.include?(supplier_id) && assignment_ids.include?(consumer_id)

        [supplier_id.to_s, consumer_id.to_s]
      end

      { nodes: nodes, links: links }
    end

    # Sankey: fixed flow layout (less "floating" than networkgraph). Good for supply → consumer.
    def highcharts_sankey_data(assignments, relationships, organization:)
      assignment_ids = assignments.map(&:id).to_set
      title_counts = assignments.group_by { |a| a.title.to_s }.transform_values(&:size)

      nodes = assignments.map do |assignment|
        title = assignment.title.to_s
        name = if title_counts[title] > 1
                 "#{title.truncate(45)} (#{assignment.id})"
               else
                 title.truncate(60)
               end

        {
          id: assignment.id.to_s,
          name: name,
          url: organization_assignment_path(organization, assignment)
        }
      end

      data = relationships.filter_map do |relationship|
        supplier_id = relationship.supplier_assignment_id
        consumer_id = relationship.consumer_assignment_id
        next unless assignment_ids.include?(supplier_id) && assignment_ids.include?(consumer_id)

        [supplier_id.to_s, consumer_id.to_s, 1]
      end

      { nodes: nodes, data: data }
    end

    def vis_network_data(assignments, relationships, organization:)
      assignment_ids = assignments.map(&:id).to_set
      nodes = assignments.map do |assignment|
        {
          id: assignment.id,
          label: assignment.title.to_s.truncate(60),
          url: organization_assignment_path(organization, assignment)
        }
      end

      edges = relationships.filter_map do |relationship|
        supplier_id = relationship.supplier_assignment_id
        consumer_id = relationship.consumer_assignment_id
        next unless assignment_ids.include?(supplier_id) && assignment_ids.include?(consumer_id)

        {
          id: relationship.id,
          from: supplier_id,
          to: consumer_id,
          arrows: 'to'
        }
      end

      { nodes: nodes, edges: edges }
    end

    def cytoscape_node_id(assignment_id)
      "a#{assignment_id}"
    end

    def organization_assignment_path(organization, assignment)
      Rails.application.routes.url_helpers.organization_assignment_path(organization, assignment)
    end
  end
end
