# frozen_string_literal: true

module AgentTools
  # Current-week goal confidence only. week_start is pinned server-side to this Monday.
  # Completing a goal (0% or 100%) requires learnings — mirrors GoalsController#complete.
  class SetCurrentWeekGoalConfidence < Base
    include Rails.application.routes.url_helpers

    def call(
      context:,
      goal_path: nil,
      goal_id: nil,
      confidence_percentage:,
      confidence_reason: nil,
      learnings: nil,
      week_start: nil,
      **_ignored
    )
      current_monday = Date.current.beginning_of_week(:monday)

      if week_start.present?
        parsed = parse_date(week_start)
        if parsed != current_monday
          return err("week_start must be the current week (#{current_monday})", code: "not_current_week")
        end
      end

      return err("goal_path is required", code: "validation_failed") if goal_path.blank? && goal_id.blank?

      goal = RecordPaths.resolve_goal(context, goal_path: goal_path, goal_id: goal_id)
      return err("goal not found", code: "not_found") if goal.nil?
      return err("goal not in organization", code: "validation_failed") unless goal.company_id == company_for(context).id
      return err("goal not viewable", code: "not_authorized") unless goal.can_be_viewed_by?(context.person)
      return err("cannot set confidence on a completed goal", code: "validation_failed") if goal.completed_at.present?
      return err("cannot set confidence on a deleted goal", code: "validation_failed") if goal.deleted_at.present?

      check_in_record = GoalCheckIn.new(goal: goal)
      context.authorize!(check_in_record, :create?)

      pct = confidence_percentage.present? ? confidence_percentage.to_i : nil
      return err("confidence_percentage is required", code: "validation_failed") if pct.nil?
      unless pct.between?(0, 100)
        return err("confidence_percentage must be between 0 and 100", code: "validation_failed")
      end

      learnings_text = learnings.to_s.strip.presence || confidence_reason.to_s.strip.presence
      if [0, 100].include?(pct) && learnings_text.blank?
        return err(
          "cannot complete a goal (0% or 100%) without learnings — ask what was learned first",
          code: "validation_failed"
        )
      end

      reason = learnings_text.presence || confidence_reason

      result = Goals::CheckInService.call(
        goal: goal,
        current_person: context.person,
        current_company_teammate: context.company_teammate,
        confidence_percentage: pct,
        confidence_reason: reason,
        week_start: current_monday
      )

      return err(result.error, code: "validation_failed") unless result.ok?

      ok(
        path: organization_goal_path(context.organization, goal),
        week_start: current_monday.iso8601,
        confidence_percentage: pct,
        completed: goal.reload.completed_at.present?,
        redirect_path: "#{organization_goal_path(context.organization, goal)}#check-in"
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    end

    private

    def company_for(context)
      org = context.organization
      org.respond_to?(:root_company) && org.root_company.present? ? org.root_company : org
    end

    def parse_date(value)
      return value if value.is_a?(Date)

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
