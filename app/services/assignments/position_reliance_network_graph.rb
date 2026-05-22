# frozen_string_literal: true

module Assignments
  # Builds a one-hop supply network around a position's required and suggested assignments.
  class PositionRelianceNetworkGraph
    Component = Struct.new(:assignments, :relationships, :elements, :root_node_ids, keyword_init: true)

    HIGHLIGHT_REQUIRED = 'required'
    HIGHLIGHT_SUGGESTED = 'suggested'
    HIGHLIGHT_EXTERNAL = 'external'

    def initialize(position:, organization:)
      @position = position
      @organization = organization
      @company_assignment_ids = Assignment.unarchived.where(company: organization).pluck(:id).to_set
      @required_assignment_ids = position_assignment_ids_for('required')
      @suggested_assignment_ids = position_assignment_ids_for('suggested')
      @position_assignment_ids = @required_assignment_ids | @suggested_assignment_ids
    end

    def show_graph?
      @position_assignment_ids.any?
    end

    def components
      return [] unless show_graph?

      visible_assignment_ids = visible_assignment_id_set
      assignments = Assignment
        .where(id: visible_assignment_ids.to_a)
        .includes(:department)
        .order(:title)
      relationships = AssignmentSupplyRelationship
        .where(supplier_assignment_id: visible_assignment_ids.to_a, consumer_assignment_id: visible_assignment_ids.to_a)
        .includes(:supplier_assignment, :consumer_assignment)

      [
        Component.new(
          assignments: assignments,
          relationships: relationships,
          elements: cytoscape_elements(assignments, relationships),
          root_node_ids: SupplyGraphElements.cytoscape_root_node_ids(relationships)
        )
      ]
    end

    private

    def position_assignment_ids_for(assignment_type)
      @position
        .position_assignments
        .where(assignment_type: assignment_type)
        .pluck(:assignment_id)
        .select { |id| @company_assignment_ids.include?(id) }
        .to_set
    end

    def visible_assignment_id_set
      @position_assignment_ids | one_removed_assignment_ids
    end

    def one_removed_assignment_ids
      return Set.new if @position_assignment_ids.empty?

      core_ids = @position_assignment_ids.to_a
      company_ids = @company_assignment_ids.to_a

      supplier_neighbors = AssignmentSupplyRelationship
        .where(consumer_assignment_id: core_ids, supplier_assignment_id: company_ids)
        .pluck(:supplier_assignment_id)
      consumer_neighbors = AssignmentSupplyRelationship
        .where(supplier_assignment_id: core_ids, consumer_assignment_id: company_ids)
        .pluck(:consumer_assignment_id)

      (supplier_neighbors + consumer_neighbors).to_set - @position_assignment_ids
    end

    def cytoscape_elements(assignments, relationships)
      assignments.map do |assignment|
        {
          group: 'nodes',
          data: {
            id: SupplyGraphElements.cytoscape_node_id(assignment.id),
            label: assignment.title.to_s.truncate(60),
            url: SupplyGraphElements.organization_assignment_path(@organization, assignment),
            highlightTier: highlight_tier_for(assignment.id)
          }
        }
      end + relationships.map do |relationship|
        {
          group: 'edges',
          data: {
            id: "e#{relationship.id}",
            source: SupplyGraphElements.cytoscape_node_id(relationship.supplier_assignment_id),
            target: SupplyGraphElements.cytoscape_node_id(relationship.consumer_assignment_id)
          }
        }
      end
    end

    def highlight_tier_for(assignment_id)
      if @required_assignment_ids.include?(assignment_id)
        HIGHLIGHT_REQUIRED
      elsif @suggested_assignment_ids.include?(assignment_id)
        HIGHLIGHT_SUGGESTED
      else
        HIGHLIGHT_EXTERNAL
      end
    end
  end
end
