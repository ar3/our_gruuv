# frozen_string_literal: true

module AgentTools
  # Validates and previews a goal field / parent-link update. Does not persist.
  # Apply with confirm_goal_change(change_token).
  class ProposeGoalUpdate < Base
    include Rails.application.routes.url_helpers

    def call(
      context:,
      goal_path: nil,
      goal_id: nil,
      title: nil,
      description: nil,
      goal_type: nil,
      privacy_level: nil,
      most_likely_target_date: nil,
      earliest_target_date: nil,
      latest_target_date: nil,
      initial_confidence: nil,
      owner_path: nil,
      owner_type: nil,
      owner_id: nil,
      add_parent_paths: nil,
      remove_parent_paths: nil,
      **_ignored
    )
      goal = GoalMutations.find_visible_goal!(context, goal_path: goal_path, goal_id: goal_id)
      context.authorize!(goal, :update?)

      return err("cannot update a deleted goal", code: "validation_failed") if goal.deleted_at.present?

      attrs = {}
      attrs[:title] = title if !title.nil?
      attrs[:description] = description if !description.nil?
      attrs[:goal_type] = goal_type if goal_type.present?
      attrs[:privacy_level] = privacy_level if privacy_level.present?
      attrs[:most_likely_target_date] = most_likely_target_date if !most_likely_target_date.nil?
      attrs[:earliest_target_date] = earliest_target_date if !earliest_target_date.nil?
      attrs[:latest_target_date] = latest_target_date if !latest_target_date.nil?
      attrs[:initial_confidence] = initial_confidence if initial_confidence.present?

      owner_change = nil
      if owner_path.present? || (owner_type.present? && owner_id.present?)
        owner_change = GoalMutations.resolve_owner!(
          context,
          owner_path: owner_path,
          owner_type: owner_type,
          owner_id: owner_id
        )
        attrs[:owner_id] = GoalMutations.owner_value_for(
          owner_type: owner_change[:type],
          owner_id: owner_change[:id]
        )
      end

      add_parents = GoalMutations.resolve_parent_goals!(context, parent_goal_paths: add_parent_paths)
      remove_parents = GoalMutations.resolve_parent_goals!(context, parent_goal_paths: remove_parent_paths)

      if attrs.empty? && add_parents.empty? && remove_parents.empty?
        return err("no updates provided", code: "validation_failed")
      end

      before = GoalMutations.serialize_goal(context, goal)
      after = before.deep_dup

      after[:title] = attrs[:title].to_s.strip if attrs.key?(:title)
      after[:description] = attrs[:description].to_s if attrs.key?(:description)
      after[:goal_type] = attrs[:goal_type] if attrs.key?(:goal_type)
      after[:privacy_level] = attrs[:privacy_level] if attrs.key?(:privacy_level)
      after[:most_likely_target_date] = attrs[:most_likely_target_date].presence if attrs.key?(:most_likely_target_date)
      after[:earliest_target_date] = attrs[:earliest_target_date].presence if attrs.key?(:earliest_target_date)
      after[:latest_target_date] = attrs[:latest_target_date].presence if attrs.key?(:latest_target_date)
      after[:initial_confidence] = attrs[:initial_confidence] if attrs.key?(:initial_confidence)

      if owner_change
        after[:owner] = {
          type: owner_change[:type] == "Organization" ? "Organization" : owner_change[:type],
          path: owner_path.presence,
          name: "(pending)"
        }
      end

      parent_paths = Array(before[:parent_paths]).dup
      remove_parents.each do |p|
        parent_paths.delete(RecordPaths.goal_path(context, p))
      end
      add_parents.each do |p|
        path = RecordPaths.goal_path(context, p)
        parent_paths << path unless parent_paths.include?(path)
      end
      after[:parent_paths] = parent_paths

      preview = {
        goal_path: RecordPaths.goal_path(context, goal),
        before: before,
        after: after,
        add_parent_paths: add_parents.map { |p| RecordPaths.goal_path(context, p) },
        remove_parent_paths: remove_parents.map { |p| RecordPaths.goal_path(context, p) }
      }

      payload = {
        goal_id: goal.id,
        attrs: attrs,
        add_parent_ids: add_parents.map(&:id),
        remove_parent_ids: remove_parents.map(&:id)
      }

      token = PendingGoalChange.store(
        context: context,
        action: "update_goal",
        payload: payload,
        preview: preview
      )

      ok(
        needs_confirmation: true,
        change_token: token,
        expires_in_seconds: PendingGoalChange::TTL.to_i,
        preview: preview,
        path: RecordPaths.goal_path(context, goal),
        redirect_path: organization_goal_path(context.organization, goal)
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ArgumentError => e
      err(e.message, code: "validation_failed")
    end
  end
end
