# frozen_string_literal: true

module Organizations
  # Query params and request → GoalAssociation authorization context for the teammate goal flow.
  module AssociableGoalFlowParams
    extend ActiveSupport::Concern

    private

    def associable_goal_flow_query_params
      {
        return_url: params[:return_url],
        return_text: params[:return_text],
        for_company_teammate_id: params[:for_company_teammate_id]
      }.compact
    end

    def assign_goal_flow_teammate_from_params(goal_association)
      goal_association.goal_flow_teammate_id = params[:for_company_teammate_id].presence
    end
  end
end
