# frozen_string_literal: true

module Organizations
  class CytoscapeGraphLayoutsController < OrganizationNamespaceBaseController
    before_action :authenticate_person!
    before_action :set_layoutable
    before_action :authorize_layoutable!

    after_action :verify_authorized

    def show
      layout = CytoscapeGraphLayout.for_layoutable(@layoutable, graph_kind: graph_kind)
      render json: layout_payload(layout)
    end

    def update
      CytoscapeGraphLayout.upsert_for!(
        layoutable: @layoutable,
        graph_kind: graph_kind,
        positions: permitted_positions,
        node_fingerprint: params.require(:node_fingerprint)
      )
      head :no_content
    end

    def destroy
      CytoscapeGraphLayout.for_layoutable(@layoutable, graph_kind: graph_kind)&.destroy
      head :no_content
    end

    private

    def graph_kind
      params[:graph_kind].presence || raise(ActionController::ParameterMissing, :graph_kind)
    end

    def set_layoutable
      @layoutable = case graph_kind
                    when "full_network"
                      company
                    when "accountability_flow"
                      policy_scope(Assignment).find(params[:assignment_id])
                    when "position_reliance"
                      policy_scope(Position).find(params[:position_id])
                    else
                      raise ActionController::BadRequest, "Invalid graph_kind"
                    end
    end

    def authorize_layoutable!
      authorize @layoutable, policy_class: CytoscapeGraphLayoutPolicy
    end

    def permitted_positions
      raw = params.require(:positions)
      raise ActionController::ParameterMissing, :positions unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

      permitted = raw.to_unsafe_h.slice(*expected_node_ids)
      permitted.transform_values do |coords|
        { "x" => coords["x"].to_f, "y" => coords["y"].to_f }
      end
    end

    def expected_node_ids
      case graph_kind
      when "full_network"
        assignment_ids = policy_scope(Assignment).where(company: company).unarchived.pluck(:id)
        relationships = AssignmentSupplyRelationship.where(
          supplier_assignment_id: assignment_ids,
          consumer_assignment_id: assignment_ids
        )
        graph_assignment_ids = (relationships.pluck(:supplier_assignment_id) + relationships.pluck(:consumer_assignment_id)).uniq
        graph_assignment_ids.map { |id| Assignments::SupplyGraphElements.cytoscape_node_id(id) }
      when "accountability_flow"
        node_ids_from_elements(assignments_accountability_flow_elements)
      when "position_reliance"
        node_ids_from_elements(positions_reliance_flow_elements)
      else
        []
      end
    end

    def node_ids_from_elements(elements)
      elements.select { |element| element[:group] == "nodes" }.map { |element| element.dig(:data, :id) }.compact
    end

    def assignments_accountability_flow_elements
      assignment = @layoutable
      graph = ::Assignments::AccountabilityFlowGraph.new(
        assignment: assignment,
        organization: @organization,
        scoped_assignment_ids: policy_scope(Assignment).where(company: company).pluck(:id)
      )
      graph.components.first&.elements || []
    end

    def positions_reliance_flow_elements
      graph = ::Assignments::PositionRelianceNetworkGraph.new(position: @layoutable, organization: @organization)
      graph.components.first&.elements || []
    end

    def layout_payload(layout)
      {
        positions: layout&.positions || {},
        node_fingerprint: layout&.node_fingerprint
      }
    end
  end
end
