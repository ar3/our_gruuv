# frozen_string_literal: true

module AgentTools
  # Current-week goal confidence only. week_start is pinned server-side to this Monday.
  # 0% or 100% completes the goal; Learnings are encouraged but not required (late vs on-time inferred from dates).
  #
  # When context.tool_pending_mutations? (MCP), this validates and returns a change_token
  # preview — call confirm_goal_change to apply. Ask OG host-confirmed contexts write immediately.
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

      reason = learnings.to_s.strip.presence || confidence_reason.to_s.strip.presence

      if context.tool_pending_mutations?
        return propose_pending(
          context: context,
          goal: goal,
          pct: pct,
          reason: reason,
          current_monday: current_monday
        )
      end

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

    def propose_pending(context:, goal:, pct:, reason:, current_monday:)
      current = goal.goal_check_ins.find_by(check_in_week_start: current_monday)
      preview = {
        goal_path: RecordPaths.goal_path(context, goal),
        week_start: current_monday.iso8601,
        before: {
          confidence_percentage: current&.confidence_percentage,
          confidence_reason: current&.confidence_reason
        },
        after: {
          confidence_percentage: pct,
          confidence_reason: reason
        }
      }

      token = PendingGoalChange.store(
        context: context,
        action: "set_confidence",
        payload: {
          goal_id: goal.id,
          confidence_percentage: pct,
          confidence_reason: reason,
          week_start: current_monday.iso8601
        },
        preview: preview
      )

      ok(
        needs_confirmation: true,
        change_token: token,
        expires_in_seconds: PendingGoalChange::TTL.to_i,
        preview: preview,
        path: organization_goal_path(context.organization, goal),
        week_start: current_monday.iso8601,
        confidence_percentage: pct,
        redirect_path: "#{organization_goal_path(context.organization, goal)}#check-in"
      )
    end

    def company_for(context)
      GoalMutations.company_for(context)
    end

    def parse_date(value)
      return value if value.is_a?(Date)

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
