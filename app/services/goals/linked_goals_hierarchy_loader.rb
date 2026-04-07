# frozen_string_literal: true

module Goals
  # Builds linked_goals (id => Goal) and linked_goal_check_ins (goal_id => latest check-in)
  # for a set of root goal IDs, including all descendants via GoalLink.
  class LinkedGoalsHierarchyLoader
    def self.call(goal_ids:)
      goal_ids = Array(goal_ids).map(&:to_i).uniq
      return { linked_goals: {}, linked_goal_check_ins: {} } if goal_ids.empty?

      all_descendant_ids = goal_ids.dup
      current_level_ids = goal_ids.dup
      while current_level_ids.any?
        next_level_ids = GoalLink.where(parent_id: current_level_ids).pluck(:child_id)
        next_level_ids.each { |id| all_descendant_ids << id unless all_descendant_ids.include?(id) }
        current_level_ids = next_level_ids
      end

      linked_goals = Goal.where(id: all_descendant_ids).includes(outgoing_links: :child).index_by(&:id)
      linked_goal_check_ins = GoalCheckIn
        .where(goal_id: all_descendant_ids)
        .includes(:confidence_reporter, :goal)
        .recent
        .group_by(&:goal_id)
        .transform_values { |check_ins| check_ins.first }

      { linked_goals: linked_goals, linked_goal_check_ins: linked_goal_check_ins }
    end
  end
end
