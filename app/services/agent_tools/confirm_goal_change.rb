# frozen_string_literal: true

module AgentTools
  # Applies a PendingGoalChange created by propose_goal_update or
  # set_current_week_goal_confidence (MCP tool_pending gate).
  class ConfirmGoalChange < Base
    include Rails.application.routes.url_helpers

    def call(context:, change_token:, **_ignored)
      return err("change_token is required", code: "validation_failed") if change_token.blank?

      pending = PendingGoalChange.consume(context: context, token: change_token)
      return err("change_token invalid or expired", code: "validation_failed") if pending.blank?

      case pending["action"]
      when "update_goal"
        apply_update(context, pending)
      when "set_confidence"
        apply_confidence(context, pending)
      else
        err("unknown pending action", code: "validation_failed")
      end
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ArgumentError => e
      err(e.message, code: "validation_failed")
    rescue ActiveRecord::RecordInvalid => e
      err(e.record.errors.full_messages.presence || e.message, code: "validation_failed")
    end

    private

    def apply_update(context, pending)
      payload = pending["payload"] || {}
      goal = Goal.find_by(id: payload["goal_id"])
      return err("goal not found", code: "not_found") if goal.nil?
      return err("goal not in organization", code: "validation_failed") unless goal.company_id == GoalMutations.company_for(context).id
      return err("goal not viewable", code: "not_authorized") unless goal.can_be_viewed_by?(context.person)

      context.authorize!(goal, :update?)

      attrs = (payload["attrs"] || {}).symbolize_keys
      add_ids = Array(payload["add_parent_ids"]).map(&:to_i)
      remove_ids = Array(payload["remove_parent_ids"]).map(&:to_i)

      PaperTrail.request.whodunnit = context.company_teammate&.id&.to_s

      ActiveRecord::Base.transaction do
        if attrs.any?
          form_attrs = attrs.dup
          form_attrs[:privacy_level] ||= goal.privacy_level
          form_attrs[:edit_check_in_permission] ||= goal.edit_check_in_permission
          form_attrs[:title] ||= goal.title
          form_attrs[:goal_type] ||= goal.goal_type
          unless form_attrs.key?(:owner_id)
            owner_type = goal.owner_type == "Organization" ? "Company" : goal.owner_type
            form_attrs[:owner_id] = "#{owner_type}_#{goal.owner_id}"
          end

          form = GoalForm.new(goal)
          form.current_person = context.person
          form.current_teammate = context.company_teammate
          unless form.validate(form_attrs) && form.save
            return err(form.errors.full_messages.presence || "could not update goal", code: "validation_failed")
          end
        end

        remove_parents = Goal.where(id: remove_ids).to_a
        add_parents = Goal.where(id: add_ids).to_a
        GoalMutations.unlink_parents!(context: context, child: goal, parents: remove_parents)
        GoalMutations.link_parents!(context: context, child: goal, parents: add_parents)
      end

      EngagementHealth.schedule_refresh_for_goal(goal.reload)

      ok(
        confirmed: true,
        action: "update_goal",
        goal: GoalMutations.serialize_goal(context, goal),
        path: RecordPaths.goal_path(context, goal),
        redirect_path: organization_goal_path(context.organization, goal)
      )
    end

    def apply_confidence(context, pending)
      payload = pending["payload"] || {}
      goal = Goal.find_by(id: payload["goal_id"])
      return err("goal not found", code: "not_found") if goal.nil?
      return err("goal not in organization", code: "validation_failed") unless goal.company_id == GoalMutations.company_for(context).id
      return err("goal not viewable", code: "not_authorized") unless goal.can_be_viewed_by?(context.person)
      return err("cannot set confidence on a completed goal", code: "validation_failed") if goal.completed_at.present?
      return err("cannot set confidence on a deleted goal", code: "validation_failed") if goal.deleted_at.present?

      check_in_record = GoalCheckIn.new(goal: goal)
      context.authorize!(check_in_record, :create?)

      pct = payload["confidence_percentage"].to_i
      reason = payload["confidence_reason"].presence
      week_start = Date.parse(payload["week_start"].to_s)

      result = Goals::CheckInService.call(
        goal: goal,
        current_person: context.person,
        current_company_teammate: context.company_teammate,
        confidence_percentage: pct,
        confidence_reason: reason,
        week_start: week_start
      )
      return err(result.error, code: "validation_failed") unless result.ok?

      ok(
        confirmed: true,
        action: "set_confidence",
        path: RecordPaths.goal_path(context, goal),
        week_start: week_start.iso8601,
        confidence_percentage: pct,
        completed: goal.reload.completed_at.present?,
        redirect_path: "#{organization_goal_path(context.organization, goal)}#check-in"
      )
    end
  end
end
