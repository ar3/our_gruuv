# frozen_string_literal: true

module AgentTools
  # Creates a draft goal (started_at nil). Parent links optional (0..n).
  # Call start_goal to activate. Does not set weekly confidence (use start_goal or
  # set_current_week_goal_confidence → confirm_goal_change on MCP).
  class CreateDraftGoal < Base
    include Rails.application.routes.url_helpers

    def call(
      context:,
      title:,
      owner_path: nil,
      owner_type: nil,
      owner_id: nil,
      goal_type: "inspirational_objective",
      description: nil,
      most_likely_target_date: nil,
      earliest_target_date: nil,
      latest_target_date: nil,
      initial_confidence: nil,
      privacy_level: nil,
      parent_goal_paths: nil,
      progressive_create_mode: nil,
      **_ignored
    )
      return err("title is required", code: "validation_failed") if title.to_s.strip.blank?
      return err("company teammate required", code: "validation_failed") if context.company_teammate.blank?

      company = GoalMutations.company_for(context)
      context.authorize!(Goal.new(company: company), :create?)

      owner = GoalMutations.resolve_owner!(
        context,
        owner_path: owner_path,
        owner_type: owner_type,
        owner_id: owner_id
      )
      parents = GoalMutations.resolve_parent_goals!(context, parent_goal_paths: parent_goal_paths)

      owner_value = GoalMutations.owner_value_for(owner_type: owner[:type], owner_id: owner[:id])
      privacy = privacy_level.presence || GoalMutations.privacy_for_owner_type(owner[:type])
      type = goal_type.presence || "inspirational_objective"
      create_mode = progressive_create_mode.to_s

      if type == "progressive_outcome" && create_mode == "expand_now"
        return expand_now(
          context: context,
          title: title,
          description: description,
          owner_value: owner_value,
          privacy: privacy,
          most_likely_target_date: most_likely_target_date,
          earliest_target_date: earliest_target_date,
          latest_target_date: latest_target_date
        )
      end

      goal = Goal.new(company: company)
      form = GoalForm.new(goal)
      form.current_person = context.person
      form.current_teammate = context.company_teammate

      payload = {
        title: title.to_s.strip,
        goal_type: type,
        description: description.to_s,
        most_likely_target_date: most_likely_target_date.presence,
        earliest_target_date: earliest_target_date.presence,
        latest_target_date: latest_target_date.presence,
        owner_id: owner_value,
        privacy_level: privacy,
        edit_check_in_permission: "anyone_who_can_view"
      }
      payload[:initial_confidence] = initial_confidence if initial_confidence.present?

      PaperTrail.request.whodunnit = context.company_teammate.id.to_s

      ActiveRecord::Base.transaction do
        unless form.validate(payload) && form.save
          return err(form.errors.full_messages.presence || "could not create goal", code: "validation_failed")
        end

        GoalMutations.link_parents!(context: context, child: goal, parents: parents)
      end

      EngagementHealth.schedule_refresh_for_goal(goal)

      ok(
        GoalMutations.serialize_goal(context, goal.reload).merge(
          draft: true,
          needs_start: true,
          path: RecordPaths.goal_path(context, goal),
          redirect_path: organization_goal_path(context.organization, goal)
        )
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ArgumentError => e
      err(e.message, code: "validation_failed")
    rescue ActiveRecord::RecordInvalid => e
      err(e.record.errors.full_messages.presence || e.message, code: "validation_failed")
    end

    private

    def expand_now(context:, title:, description:, owner_value:, privacy:, most_likely_target_date:, earliest_target_date:, latest_target_date:)
      result = Goals::ExpandProgressiveOutcome.call(
        organization: context.organization,
        current_person: context.person,
        current_teammate: context.company_teammate,
        attrs: {
          title: title.to_s.strip,
          description: description,
          owner_id: owner_value,
          privacy_level: privacy,
          most_likely_target_date: most_likely_target_date,
          earliest_target_date: earliest_target_date,
          latest_target_date: latest_target_date
        }
      )
      return err(result.error, code: "validation_failed") unless result.ok?

      ok(
        GoalMutations.serialize_goal(context, result.parent).merge(
          draft: true,
          needs_start: true,
          expand_now: true,
          child_paths: result.children.map { |c| RecordPaths.goal_path(context, c) },
          path: RecordPaths.goal_path(context, result.parent),
          redirect_path: organization_goal_path(context.organization, result.parent)
        )
      )
    end
  end
end
