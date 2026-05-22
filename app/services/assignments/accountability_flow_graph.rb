# frozen_string_literal: true

module Assignments
  # Builds Cytoscape-ready elements for the connected supply-chain component
  # that includes a focal assignment (supplier → consumer directed edges).
  class AccountabilityFlowGraph
    Component = Struct.new(:assignments, :relationships, :elements, :root_node_ids, keyword_init: true)

    def initialize(assignment:, organization:, scoped_assignment_ids:)
      @assignment = assignment
      @organization = organization
      @scoped_assignment_ids = scoped_assignment_ids.to_set
    end

    def has_supply_links?
      return false if @scoped_assignment_ids.exclude?(@assignment.id)

      AssignmentSupplyRelationship
        .where(supplier_assignment_id: @assignment.id)
        .or(AssignmentSupplyRelationship.where(consumer_assignment_id: @assignment.id))
        .exists?
    end

    def components
      return [] unless has_supply_links?

      component_ids = connected_component_assignment_ids
      assignments = Assignment
        .where(id: component_ids)
        .includes(:department)
        .order(:title)
      relationships = AssignmentSupplyRelationship
        .where(supplier_assignment_id: component_ids, consumer_assignment_id: component_ids)
        .includes(:supplier_assignment, :consumer_assignment)

      [
        Component.new(
          assignments: assignments,
          relationships: relationships,
          elements: SupplyGraphElements.cytoscape_elements(
            assignments,
            relationships,
            organization: @organization,
            current_assignment_id: @assignment.id
          ),
          root_node_ids: SupplyGraphElements.cytoscape_root_node_ids(relationships)
        )
      ]
    end

    private

    def connected_component_assignment_ids
      adjacency = adjacency_for_scope
      visited = Set.new
      queue = [@assignment.id]

      until queue.empty?
        current_id = queue.shift
        next if visited.include?(current_id)

        visited.add(current_id)
        (adjacency[current_id] || []).each do |neighbor_id|
          queue << neighbor_id unless visited.include?(neighbor_id)
        end
      end

      visited
    end

    def adjacency_for_scope
      relationships = AssignmentSupplyRelationship.where(
        supplier_assignment_id: @scoped_assignment_ids.to_a,
        consumer_assignment_id: @scoped_assignment_ids.to_a
      )

      adjacency = Hash.new { |hash, key| hash[key] = Set.new }
      relationships.find_each do |relationship|
        supplier_id = relationship.supplier_assignment_id
        consumer_id = relationship.consumer_assignment_id
        adjacency[supplier_id] << consumer_id
        adjacency[consumer_id] << supplier_id
      end
      adjacency.transform_values(&:to_a)
    end

  end
end
