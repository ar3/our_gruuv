# frozen_string_literal: true

module Organizations
  module LoadAssociableGoalsDisplay
    extend ActiveSupport::Concern

    included do
      include AssociableGoalsHelper
    end

    private

    # Sets @associated_linked_goals, @associated_linked_goal_check_ins, @associated_goal_association_by_goal_id
    def load_associable_goals_display!(associable)
      goal_ids = associable.goals.pluck(:id)
      if goal_ids.any?
        data = Goals::LinkedGoalsHierarchyLoader.call(goal_ids: goal_ids)
        @associated_linked_goals = data[:linked_goals]
        @associated_linked_goal_check_ins = data[:linked_goal_check_ins]
      else
        @associated_linked_goals = {}
        @associated_linked_goal_check_ins = {}
      end
      @associated_goal_association_by_goal_id = associable.goal_associations.includes(:goal).index_by(&:goal_id)
    end
  end
end
