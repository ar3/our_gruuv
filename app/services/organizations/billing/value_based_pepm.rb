# frozen_string_literal: true

module Organizations
  module Billing
    # Average value-per-employee from the Value page unit rates, for PEPM preview.
    class ValueBasedPepm
      WEEKLY_MILESTONE_VALUE = 1.0
      WEEKLY_OBSERVEE_VALUE = 0.5
      WEEKLY_CHECK_IN_VALUE = 0.5
      WEEKLY_GOAL_CHECK_IN_VALUE = 0.25
      WEEKLY_CONSULTATION_VALUE = 1.0
      APPROX_WEEKS_PER_MONTH = 4.3

      def initialize(organization)
        @organization = organization
      end

      def call(range: 90.days.ago..Time.current)
        stories_count, = stories_counts(range)
        stand_count, = stand_counts(range)
        growth_count, = growth_counts(range)
        goals_count, = goal_progress_counts(range)
        consultation_count, = consultation_counts(range)

        total_value =
          (stories_count * WEEKLY_OBSERVEE_VALUE) +
          (stand_count * WEEKLY_CHECK_IN_VALUE) +
          (growth_count * WEEKLY_MILESTONE_VALUE) +
          (goals_count * WEEKLY_GOAL_CHECK_IN_VALUE) +
          (consultation_count * WEEKLY_CONSULTATION_VALUE)

        week_count = [
          ((range.end.to_date - range.begin.to_date).to_f / 7.0).ceil,
          1
        ].max
        teammate_count = CompanyTeammate.for_organization_hierarchy(@organization).employed.count

        per_employee_week =
          if week_count.positive? && teammate_count.positive?
            total_value.to_f / week_count / teammate_count
          end
        per_employee_month = per_employee_week && (per_employee_week * APPROX_WEEKS_PER_MONTH)

        {
          total_value: total_value.to_f,
          week_count: week_count,
          teammate_count: teammate_count,
          per_employee_week: per_employee_week,
          per_employee_month: per_employee_month,
          range_begin: range.begin.to_date,
          range_end: range.end.to_date
        }
      end

      private

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

      def goal_progress_counts(chart_range)
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
        [scope.count, scope.where.not(triggered_by_teammate_id: nil).distinct.count(:triggered_by_teammate_id)]
      end
    end
  end
end
