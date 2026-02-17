# frozen_string_literal: true

module Goals
  # Returns the set of goal IDs that are "in hierarchy" for a given goal:
  # the goal itself, all ancestors (recursive parents), and all descendants (recursive children).
  # Used to disable those goals on associate-existing pages (e.g. parent/child linking).
  class GoalHierarchyIdsQuery
    def initialize(goal)
      @goal = goal
    end

    def call
      Set.new.tap do |ids|
        ids.add(@goal.id)
        ids.merge(ancestor_ids)
        ids.merge(descendant_ids)
      end
    end

    private

    def ancestor_ids
      return [] unless @goal.persisted?

      visited = Set.new
      queue = GoalLink.where(child_id: @goal.id).pluck(:parent_id).uniq

      while queue.any?
        parent_id = queue.shift
        next if visited.include?(parent_id)

        visited.add(parent_id)
        queue.concat(GoalLink.where(child_id: parent_id).pluck(:parent_id).uniq)
      end

      visited
    end

    def descendant_ids
      return [] unless @goal.persisted?

      visited = Set.new
      queue = GoalLink.where(parent_id: @goal.id).pluck(:child_id).uniq

      while queue.any?
        child_id = queue.shift
        next if visited.include?(child_id)

        visited.add(child_id)
        queue.concat(GoalLink.where(parent_id: child_id).pluck(:child_id).uniq)
      end

      visited
    end
  end
end
