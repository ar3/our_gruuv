# frozen_string_literal: true

# Engagement Health: shared Healthy / At Risk / Needs Attention vocabulary
# across five categories (OGO given, OGO received, goal confidence, required
# clarity check-ins, milestones). Deliberately NOT "on/off track", which
# already describes a goal's outcome trajectory — these statuses describe the
# freshness/coverage of engagement signals. This module and its children are
# the SINGLE source of truth for statuses, thresholds, and the
# worst-status-wins rollup — no other code path may reimplement these
# definitions.
module EngagementHealth
  HEALTHY = "healthy"
  AT_RISK = "at_risk"
  NEEDS_ATTENTION = "needs_attention"
  STATUSES = [HEALTHY, AT_RISK, NEEDS_ATTENTION].freeze

  CATEGORY_OGO_GIVEN = "ogo_given"
  CATEGORY_OGO_RECEIVED = "ogo_received"
  CATEGORY_GOAL_CONFIDENCE = "goal_confidence"
  CATEGORY_REQUIRED_CLARITY = "required_clarity"
  CATEGORY_MILESTONES = "milestones"
  CATEGORIES = [
    CATEGORY_OGO_GIVEN,
    CATEGORY_OGO_RECEIVED,
    CATEGORY_GOAL_CONFIDENCE,
    CATEGORY_REQUIRED_CLARITY,
    CATEGORY_MILESTONES
  ].freeze

  CATEGORY_LABELS = {
    CATEGORY_OGO_GIVEN => "OGOs Given",
    CATEGORY_OGO_RECEIVED => "OGOs Received",
    CATEGORY_GOAL_CONFIDENCE => "Goal Confidence",
    CATEGORY_REQUIRED_CLARITY => "Required Clarity Check-Ins",
    CATEGORY_MILESTONES => "Milestones"
  }.freeze

  STATUS_LABELS = {
    HEALTHY => "Healthy",
    AT_RISK => "At Risk",
    NEEDS_ATTENTION => "Needs Attention"
  }.freeze

  module_function

  # Rollup rule: worst status wins.
  def worst_status(statuses)
    return HEALTHY if statuses.blank?

    STATUSES.reverse.find { |status| statuses.include?(status) } || HEALTHY
  end

  # 0 = worst (Needs Attention), increasing toward best; unknown statuses sort last.
  def status_severity_rank(status)
    STATUSES.reverse.index(status) || STATUSES.size
  end

  def row_key(category:, level:, entity_type:, entity_id:)
    [category, level, entity_type, entity_id].map(&:to_s).join("|")
  end

  # Event-driven update path: services/controllers that perform qualifying
  # writes call these so users never see a stale status after taking action
  # (no model callbacks). The daily job covers time-based decay.
  def schedule_refresh_for(teammate_id)
    return if teammate_id.blank?

    EngagementHealthRefreshJob.perform_later(teammate_id)
  end

  def schedule_refresh_for_goal(goal)
    return unless goal&.owner_type == "CompanyTeammate"

    schedule_refresh_for(goal.owner_id)
  end

  # OGO publish/unpublish/archive/restore affects the observer and every observee.
  def schedule_refresh_for_observation(observation)
    Observations::HealthCacheRefresh.teammate_ids_for(observation).each do |teammate_id|
      schedule_refresh_for(teammate_id)
    end
  end
end
