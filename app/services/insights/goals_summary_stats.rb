# frozen_string_literal: true

module Insights
  # Headline totals for Insights → Goals: created, confidence-checked, stale, and completed
  # goals in a timespan, plus distinct teammates for each bucket.
  class GoalsSummaryStats
    Result = Struct.new(
      :created_goals_count,
      :created_teammates_count,
      :confidence_checked_goals_count,
      :confidence_checked_teammates_count,
      :stale_goals_count,
      :stale_teammates_count,
      :completed_goals_count,
      :completed_teammates_count,
      keyword_init: true
    )

    def initialize(goals_scope:, range:)
      @goals_scope = goals_scope
      @range = range
    end

    def call
      Result.new(
        created_goals_count: created_scope.count,
        created_teammates_count: created_scope.distinct.count(:creator_id),
        confidence_checked_goals_count: confidence_checked_goal_ids.size,
        confidence_checked_teammates_count: confidence_checked_teammates_count,
        stale_goals_count: stale_scope.count,
        stale_teammates_count: stale_teammates_count,
        completed_goals_count: completed_scope.count,
        completed_teammates_count: completed_teammates_count
      )
    end

    private

    attr_reader :goals_scope, :range

    def created_scope
      @created_scope ||= goals_scope.where(created_at: range)
    end

    def completed_scope
      @completed_scope ||= goals_scope.where(completed_at: range)
    end

    def check_ins_in_range
      @check_ins_in_range ||= GoalCheckIn
        .where(goal_id: goals_scope.select(:id))
        .where(created_at: range)
    end

    def confidence_checked_goal_ids
      @confidence_checked_goal_ids ||= check_ins_in_range.distinct.pluck(:goal_id)
    end

    def confidence_checked_teammates_count
      check_ins_in_range.distinct.count(:confidence_reporter_id)
    end

    # Created before the timespan with no confidence checks during the timespan.
    def stale_scope
      @stale_scope ||= goals_scope
        .where(created_at: ...range.begin)
        .where.not(id: confidence_checked_goal_ids)
    end

    def stale_teammates_count
      stale_scope
        .where(owner_type: "CompanyTeammate")
        .distinct
        .count(:owner_id)
    end

    def completed_teammates_count
      completed_scope
        .where(owner_type: "CompanyTeammate")
        .distinct
        .count(:owner_id)
    end
  end
end
