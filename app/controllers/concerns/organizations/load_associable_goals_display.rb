# frozen_string_literal: true

module Organizations
  module LoadAssociableGoalsDisplay
    extend ActiveSupport::Concern

    included do
      include AssociableGoalsHelper
    end

    private

    # Sets @visible_associable_goals, @associated_linked_goals, @associated_linked_goal_check_ins,
    # and @associated_goal_association_by_goal_id (privacy- and teammate-lens-scoped).
    def load_associable_goals_display!(associable, subject_teammate: nil)
      data = Goals::VisibleAssociableGoalsForDisplay.new(
        associable: associable,
        viewer: current_person,
        goals_scope: policy_scope(Goal),
        subject_teammate: subject_teammate
      ).call

      @visible_associable_goals = data[:goals]
      @associated_linked_goals = data[:linked_goals]
      @associated_linked_goal_check_ins = data[:linked_goal_check_ins]
      @associated_goal_association_by_goal_id = data[:goal_association_by_goal_id]
    end
  end
end
