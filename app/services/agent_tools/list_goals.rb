# frozen_string_literal: true

module AgentTools
  # Goals visible to the caller: policy_scope → FilterQuery → can_be_viewed_by?.
  class ListGoals < Base
    DEFAULT_LIMIT = 25

    def call(context:, needing_check_in: false, limit: DEFAULT_LIMIT, **_ignored)
      context.authorize!(context.organization, :show?)

      goals =
        if ActiveModel::Type::Boolean.new.cast(needing_check_in)
          GoalsNeedingCheckInQuery.new(teammate: context.company_teammate).call
        else
          scoped = context.policy_scope(Goal)
          Goals::FilterQuery.new(scoped).call(show_deleted: false, show_completed: false).to_a
        end

      visible = Array(goals).select { |goal| goal.can_be_viewed_by?(context.person) }
      limited = visible.first(limit.to_i.clamp(1, 50))

      ok(
        goals: limited.map { |g| serialize(context, g) },
        count: limited.size,
        needing_check_in: ActiveModel::Type::Boolean.new.cast(needing_check_in)
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    end

    private

    def serialize(context, goal)
      {
        title: goal.title,
        path: RecordPaths.goal_path(context, goal),
        most_likely_target_date: goal.most_likely_target_date&.iso8601
      }
    end
  end
end
