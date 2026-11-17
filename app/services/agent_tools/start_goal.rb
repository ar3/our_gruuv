# frozen_string_literal: true

module AgentTools
  # Starts a draft goal (sets started_at). Optional current-week confidence applies
  # via CheckInService (which also starts the goal if still draft).
  class StartGoal < Base
    include Rails.application.routes.url_helpers

    def call(
      context:,
      goal_path: nil,
      goal_id: nil,
      confidence_percentage: nil,
      confidence_reason: nil,
      learnings: nil,
      **_ignored
    )
      goal = GoalMutations.find_visible_goal!(context, goal_path: goal_path, goal_id: goal_id)
      context.authorize!(goal, :update?)

      return err("goal is completed", code: "validation_failed") if goal.completed_at.present?
      return err("goal is deleted", code: "validation_failed") if goal.deleted_at.present?
      return err("goal is already started", code: "validation_failed") if goal.started_at.present?

      pct = confidence_percentage.nil? ? nil : confidence_percentage.to_i
      if !pct.nil? && !pct.between?(0, 100)
        return err("confidence_percentage must be between 0 and 100", code: "validation_failed")
      end

      reason = learnings.to_s.strip.presence || confidence_reason.to_s.strip.presence
      PaperTrail.request.whodunnit = context.company_teammate&.id&.to_s

      if pct.nil?
        unless goal.update(started_at: Time.current)
          return err(goal.errors.full_messages.presence || "failed to start goal", code: "validation_failed")
        end
      else
        check_in_record = GoalCheckIn.new(goal: goal)
        context.authorize!(check_in_record, :create?)

        result = Goals::CheckInService.call(
          goal: goal,
          current_person: context.person,
          current_company_teammate: context.company_teammate,
          confidence_percentage: pct,
          confidence_reason: reason,
          week_start: Date.current.beginning_of_week(:monday)
        )
        return err(result.error, code: "validation_failed") unless result.ok?
      end

      EngagementHealth.schedule_refresh_for_goal(goal.reload)

      ok(
        GoalMutations.serialize_goal(context, goal).merge(
          draft: false,
          started: true,
          confidence_percentage: pct,
          week_start: pct.nil? ? nil : Date.current.beginning_of_week(:monday).iso8601,
          path: RecordPaths.goal_path(context, goal),
          redirect_path: organization_goal_path(context.organization, goal)
        )
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ArgumentError => e
      err(e.message, code: "validation_failed")
    end
  end
end
