# frozen_string_literal: true

module EngagementHealth
  # Shared Goal Confidence scoring for any polymorphic goal owner
  # (CompanyTeammate today; Team for Teams Health). Keep thresholds and
  # item-set rules here so teammate and team rollups cannot drift.
  module GoalConfidence
    module_function

    # Active (started, not completed) plus completed within the window; drafts out.
    def scorable_goals(owner_type:, owner_id:, reference_time: Time.current)
      window_start = reference_time - Thresholds::COMPLETED_GOAL_WINDOW_DAYS.days
      Goal.unscoped
        .where(owner_type: owner_type, owner_id: owner_id)
        .where("goals.created_at <= ?", reference_time)
        .where("goals.deleted_at IS NULL OR goals.deleted_at > ?", reference_time)
        .where(
          "(started_at IS NOT NULL AND started_at <= ? AND (completed_at IS NULL OR completed_at > ?)) " \
          "OR (completed_at >= ? AND completed_at <= ?)",
          reference_time, reference_time, window_start, reference_time
        )
        .includes(:goal_check_ins)
        .order(:created_at)
    end

    def scorable_goals_for_owners(owner_type:, owner_ids:, reference_time: Time.current)
      return Goal.none if owner_ids.blank?

      window_start = reference_time - Thresholds::COMPLETED_GOAL_WINDOW_DAYS.days
      Goal.unscoped
        .where(owner_type: owner_type, owner_id: owner_ids)
        .where("goals.created_at <= ?", reference_time)
        .where("goals.deleted_at IS NULL OR goals.deleted_at > ?", reference_time)
        .where(
          "(started_at IS NOT NULL AND started_at <= ? AND (completed_at IS NULL OR completed_at > ?)) " \
          "OR (completed_at >= ? AND completed_at <= ?)",
          reference_time, reference_time, window_start, reference_time
        )
        .includes(:goal_check_ins)
        .order(:created_at)
    end

    def status_for_goal(goal, reference_time: Time.current)
      last_check_in = goal.goal_check_ins
        .select { |check_in| check_in.updated_at <= reference_time }
        .max_by(&:updated_at)
      Thresholds.status_for_last_event(
        last_check_in&.updated_at,
        healthy_within: Thresholds::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS,
        needs_attention_at: Thresholds::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS,
        reference_time: reference_time
      )
    end

    # Best-status-wins rollup. Empty scorable set → Needs Attention.
    def rollup_status(goals, reference_time: Time.current)
      if goals.blank?
        return {
          status: NEEDS_ATTENTION,
          empty_reason: "never_started_or_completed_a_goal",
          item_statuses: []
        }
      end

      item_statuses = goals.map { |goal| status_for_goal(goal, reference_time: reference_time) }
      {
        status: EngagementHealth.best_status(item_statuses),
        empty_reason: nil,
        item_statuses: item_statuses
      }
    end

    def rollup_status_for_owner(owner_type:, owner_id:, reference_time: Time.current)
      goals = scorable_goals(owner_type: owner_type, owner_id: owner_id, reference_time: reference_time).to_a
      rollup_status(goals, reference_time: reference_time)
    end

    def stale?(status)
      status == WARNING || status == NEEDS_ATTENTION
    end
  end
end
