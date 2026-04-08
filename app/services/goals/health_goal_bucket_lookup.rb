# frozen_string_literal: true

require "set"

module Goals
  # Single batched lookup for partitioning goals into associated / unassociated / child buckets.
  # Use one instance per request (or CSV export) after loading all visible goal ids.
  class HealthGoalBucketLookup
    def self.load_for_goal_ids(goal_ids)
      goal_ids = Array(goal_ids).compact.uniq
      return new(Set.new, Set.new) if goal_ids.empty?

      child_ids = GoalLink.where(child_id: goal_ids).pluck(:child_id).to_set
      assoc_ids = GoalAssociation.where(goal_id: goal_ids).distinct.pluck(:goal_id)
      prompt_ids = PromptGoal.where(goal_id: goal_ids).distinct.pluck(:goal_id)
      new(child_ids, Set.new(assoc_ids + prompt_ids))
    end

    attr_reader :child_goal_ids, :associated_goal_ids

    def initialize(child_goal_ids, associated_goal_ids)
      @child_goal_ids = child_goal_ids
      @associated_goal_ids = associated_goal_ids
    end

    def partition(goals)
      associated = []
      unassociated = []
      child = []

      goals.each do |goal|
        if child_goal_ids.include?(goal.id)
          child << goal
        elsif associated_goal_ids.include?(goal.id)
          associated << goal
        else
          unassociated << goal
        end
      end

      { associated: associated, unassociated: unassociated, child: child }
    end
  end
end
