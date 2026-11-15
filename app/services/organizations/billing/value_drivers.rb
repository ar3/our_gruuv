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
          activity_count = activity_count_for(driver[:key], range)
          {
            key: driver[:key],
            label: driver[:label],
            activity_count: activity_count,
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

      def activity_count_for(key, range)
        case key
        when :stories then stories_count(range)
        when :stand then stand_count(range)
        when :growth then growth_count(range)
        when :goals then goals_count(range)
        when :consultations then consultation_count(range)
        else 0
        end
      end

      def stories_count(chart_range)
        Observee
          .joins(:observation)
          .where(observations: { company_id: @organization.id })
          .merge(Observation.not_soft_deleted.published)
          .where(observations: { published_at: chart_range })
          .count
      end

      def stand_count(chart_range)
        teammate_ids_scope = CompanyTeammate.for_organization_hierarchy(@organization).select(:id)
        AssignmentCheckIn.where(teammate_id: teammate_ids_scope, official_check_in_completed_at: chart_range).count +
          AspirationCheckIn.where(teammate_id: teammate_ids_scope, official_check_in_completed_at: chart_range).count +
          PositionCheckIn.where(teammate_id: teammate_ids_scope, official_check_in_completed_at: chart_range).count
      end

      def growth_count(chart_range)
        teammate_ids_scope = CompanyTeammate.for_organization_hierarchy(@organization).select(:id)
        TeammateMilestone
          .where(teammate_id: teammate_ids_scope)
          .where(attained_at: chart_range.begin.to_date..chart_range.end.to_date)
          .count
      end

      def goals_count(chart_range)
        GoalCheckIn
          .joins(:goal)
          .where(goals: { company_id: @organization.id })
          .where(created_at: chart_range)
          .count
      end

      def consultation_count(chart_range)
        OgConsultation
          .billable
          .completed
          .where(organization_id: @organization.id)
          .where(
            "COALESCE(og_consultations.completed_at, og_consultations.created_at) BETWEEN ? AND ?",
            chart_range.begin,
            chart_range.end
          )
          .count
      end
    end
  end
end
