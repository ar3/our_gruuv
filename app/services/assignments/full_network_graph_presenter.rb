# frozen_string_literal: true

module Assignments
  # Prepares visualization payloads for the organization-wide assignment supply network.
  class FullNetworkGraphPresenter
    def initialize(assignments:, supply_relationships:, organization:)
      @assignments = assignments
      @supply_relationships = supply_relationships
      @organization = organization
    end

    def cytoscape_elements
      SupplyGraphElements.cytoscape_elements(
        @assignments,
        @supply_relationships,
        organization: @organization
      )
    end

    def cytoscape_root_node_ids
      SupplyGraphElements.cytoscape_root_node_ids(@supply_relationships)
    end

    def highcharts_network_graph_data
      SupplyGraphElements.highcharts_network_graph_data(
        @assignments,
        @supply_relationships,
        organization: @organization
      )
    end

    def highcharts_sankey_data
      SupplyGraphElements.highcharts_sankey_data(
        @assignments,
        @supply_relationships,
        organization: @organization
      )
    end

    def vis_network_data
      SupplyGraphElements.vis_network_data(@assignments, @supply_relationships, organization: @organization)
    end
  end
end
