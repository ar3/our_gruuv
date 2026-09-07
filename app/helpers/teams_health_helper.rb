# frozen_string_literal: true

module TeamsHealthHelper
  GOAL_CONFIDENCE_HEALTHY_DAYS = EngagementHealth::Thresholds::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS
  GOAL_CONFIDENCE_NEEDS_ATTENTION_DAYS = EngagementHealth::Thresholds::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS
  COMPLETED_GOAL_WINDOW_DAYS = EngagementHealth::Thresholds::COMPLETED_GOAL_WINDOW_DAYS

  def teams_health_definition_lines
    [
      "Team Goal Confidence uses the same Gruuv Health rules as teammate Goal Confidence.",
      "Only Team-owned goals are scored (not members' personal goals).",
      "Scored goals: active goals plus goals completed in the last #{COMPLETED_GOAL_WINDOW_DAYS} days (drafts are not scored).",
      "Best status wins for the team. Healthy — checked within #{GOAL_CONFIDENCE_HEALTHY_DAYS} days. Warning — #{GOAL_CONFIDENCE_HEALTHY_DAYS + 1}–#{GOAL_CONFIDENCE_NEEDS_ATTENTION_DAYS - 1} days. Needs Attention — ≥ #{GOAL_CONFIDENCE_NEEDS_ATTENTION_DAYS} days, never, or no scored Team-owned goals."
    ]
  end
end
