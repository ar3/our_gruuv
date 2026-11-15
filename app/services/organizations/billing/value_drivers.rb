# frozen_string_literal: true

module Organizations
  module Billing
    # Shared Value-page unit rates and per-driver totals for a date range.
    class ValueDrivers
      WEEKLY_MILESTONE_VALUE = 1.0
      WEEKLY_OBSERVEE_VALUE = 0.5
      WEEKLY_CHECK_IN_VALUE = 0.5
      WEEKLY_GOAL_CHECK_IN_VALUE = 0.25
      WEEKLY_CONSULTATION_VALUE = 1.0

      DRIVERS = [
        { key: :stories, label: "Capture our Stories", unit_value: WEEKLY_OBSERVEE_VALUE },
        { key: :stand, label: "Know where they Stand", unit_value: WEEKLY_CHECK_IN_VALUE },
        { key: :growth, label: "Clarify Growth Paths", unit_value: WEEKLY_MILESTONE_VALUE },
        { key: :goals, label: "Progress Goals", unit_value: WEEKLY_GOAL_CHECK_IN_VALUE },
        { key: :consultations, label: "OG Consultations", unit_value: WEEKLY_CONSULTATION_VALUE }
      ].freeze

      def initialize(organization)
        @organization = organization
      end

      def breakdown(range)
        range = normalize_range(range)
        DRIVERS.map do |driver|
          activity_count, teammate_count = counts_for(driver[:key], range)
          {
            key: driver[:key],
            label: driver[:label],
            activity_count: activity_count,
            teammate_count: teammate_count,
            value_sum: activity_count * driver[:unit_value]
          }
        end
      end

      def total_value(range)
        breakdown(range).sum { |row| row[:value_sum] }
      end

      private

      def normalize_range(range)
        range.begin.to_time.beginning_of_day..range.end.to_time.end_of_day
      end

      def counts_for(key, range)
        case key
        when :stories then stories_counts(range)
        when :stand then stand_counts(range)
        when :growth then growth_counts(range)
        when :goals then goals_counts(range)
        when :consultations then consultation_counts(range)
        else [0, 0]
        end
      end

      def stories_counts(chart_range)
        scope = Observee
          .joins(:observation)
          .where(observations: { company_id: @organization.id })
          .merge(Observation.not_soft_deleted.published)
          .where(observations: { published_at: chart_range })

        [scope.count, scope.distinct.count(:teammate_id)]
      end

      def stand_counts(chart_range)
        teammate_ids_scope = CompanyTeammate.for_organization_hierarchy(@organization).select(:id)

        assignment_scope = AssignmentCheckIn
          .where(teammate_id: teammate_ids_scope, official_check_in_completed_at: chart_range)
        aspiration_scope = AspirationCheckIn
          .where(teammate_id: teammate_ids_scope, official_check_in_completed_at: chart_range)
        position_scope = PositionCheckIn
          .where(teammate_id: teammate_ids_scope, official_check_in_completed_at: chart_range)

        activity_count = assignment_scope.count + aspiration_scope.count + position_scope.count
        teammate_ids = assignment_scope.distinct.pluck(:teammate_id) |
          aspiration_scope.distinct.pluck(:teammate_id) |
          position_scope.distinct.pluck(:teammate_id)

        [activity_count, teammate_ids.size]
      end

      def growth_counts(chart_range)
        teammate_ids_scope = CompanyTeammate.for_organization_hierarchy(@organization).select(:id)
        scope = TeammateMilestone
          .where(teammate_id: teammate_ids_scope)
          .where(attained_at: chart_range.begin.to_date..chart_range.end.to_date)

        [scope.count, scope.distinct.count(:teammate_id)]
      end

      def goals_counts(chart_range)
        scope = GoalCheckIn
          .joins(:goal)
          .where(goals: { company_id: @organization.id })
          .where(created_at: chart_range)

        [scope.count, scope.distinct.count("goals.creator_id")]
      end

      def consultation_counts(chart_range)
        scope = OgConsultation
          .billable
          .completed
          .where(organization_id: @organization.id)
          .where(
            "COALESCE(og_consultations.completed_at, og_consultations.created_at) BETWEEN ? AND ?",
            chart_range.begin,
            chart_range.end
          )
        activity_count = scope.count
        teammate_count = scope.where.not(triggered_by_teammate_id: nil).distinct.count(:triggered_by_teammate_id)
        [activity_count, teammate_count]
      end
    end
  end
end
