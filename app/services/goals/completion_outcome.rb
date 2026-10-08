# frozen_string_literal: true

module Goals
  # Terminal completion outcome from the latest confidence check-in.
  # Hit = 100% (includes hit late); miss = 0%; anything else is ambiguous data.
  module CompletionOutcome
    module_function

    def from_confidence(confidence_percentage)
      case confidence_percentage
      when 100 then :hit
      when 0 then :miss
      else nil
      end
    end

    # { goal_id => confidence_percentage } for the most recent check-in per goal.
    def latest_confidence_by_goal_id(goal_ids)
      ids = Array(goal_ids).compact.uniq
      return {} if ids.empty?

      GoalCheckIn
        .where(goal_id: ids)
        .select("DISTINCT ON (goal_id) goal_id, confidence_percentage")
        .order(Arel.sql("goal_id, check_in_week_start DESC"))
        .each_with_object({}) { |row, hash| hash[row.goal_id] = row.confidence_percentage }
    end

    # { goal_id => :hit | :miss | nil }
    def for_goal_ids(goal_ids)
      latest_confidence_by_goal_id(goal_ids).transform_values { |pct| from_confidence(pct) }
    end
  end
end
