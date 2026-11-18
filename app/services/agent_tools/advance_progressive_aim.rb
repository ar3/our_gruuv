# frozen_string_literal: true

module AgentTools
  # MCP/host tool: hit current Progressive Outcome aim and create the next linked aim.
  class AdvanceProgressiveAim < Base
    include Rails.application.routes.url_helpers

    def call(context:, goal_path: nil, goal_id: nil, **_ignored)
      goal = GoalMutations.find_visible_goal!(context, goal_path: goal_path, goal_id: goal_id)
      context.authorize!(goal, :update?)

      if context.tool_pending_mutations?
        preview = {
          goal_path: RecordPaths.goal_path(context, goal),
          from_aim: goal.progressive_current_aim,
          to_aim: goal.progressive_next_aim,
          next_title_preview: Goals::ProgressiveOutcomeProse.rewrite_after_hit(
            goal.title,
            hit_aim: goal.progressive_current_aim.presence || "commit"
          )
        }
        token = PendingGoalChange.store(
          context: context,
          action: "advance_progressive_aim",
          payload: { goal_id: goal.id },
          preview: preview
        )
        return ok(
          needs_confirmation: true,
          change_token: token,
          expires_in_seconds: PendingGoalChange::TTL.to_i,
          preview: preview,
          path: RecordPaths.goal_path(context, goal)
        )
      end

      result = Goals::AdvanceProgressiveAim.call(
        goal: goal,
        current_person: context.person,
        current_teammate: context.company_teammate
      )
      return err(result.error, code: "validation_failed") unless result.ok?

      ok(
        confirmed: true,
        completed_goal: GoalMutations.serialize_goal(context, result.completed_goal),
        next_goal: GoalMutations.serialize_goal(context, result.next_goal),
        path: RecordPaths.goal_path(context, result.next_goal),
        redirect_path: organization_goal_path(context.organization, result.next_goal)
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ArgumentError => e
      err(e.message, code: "validation_failed")
    end
  end
end
