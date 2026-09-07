# frozen_string_literal: true

module GoalsBulkEditHelper
  GOAL_TYPE_OPTIONS = [
    ["Objective", "inspirational_objective"],
    ["Qualitative KR", "qualitative_key_result"],
    ["Quantitative KR", "quantitative_key_result"],
    ["Activity/Output", "stepping_stone_activity"]
  ].freeze

  PROGRESS_STATUS_COPY = {
    good_green: {
      title: "On Track",
      body: "Dark green means this goal is On Track (strong confidence relative to the remaining time to the most-likely date)."
    },
    green: {
      title: "On Track",
      body: "Light green means this goal is On Track (confidence matches the expected band for the remaining time to the most-likely date)."
    },
    yellow: {
      title: "Barely On-Track",
      body: "Yellow means this goal is Barely On-Track (confidence is in the lower On Track band for the remaining time to the most-likely date)."
    },
    red: {
      title: "Off Track",
      body: "Red means this goal is Off Track (confidence is below the expected band for the remaining time to the most-likely date)."
    },
    na: {
      title: "Started — track color not available",
      body: "Blue means the goal is started, but On Track / Off Track color is not available yet (needs a due date and a confidence check-in)."
    }
  }.freeze

  def goals_bulk_edit_row_classes(goal)
    classes = ["goals-sheet-row", "mb-2", "rounded-end"]
    if goal.started_at.blank?
      classes << "goals-sheet-row--draft"
    else
      status = goal.progress_status
      classes << "goals-sheet-row--active"
      classes << "goals-sheet-row--#{status}"
      eh = EngagementHealth::GoalConfidence.status_for_goal(goal)
      classes << "goals-sheet-row--stale" if EngagementHealth::GoalConfidence.stale?(eh)
    end
    classes.join(" ")
  end

  def goals_bulk_edit_border_popover_title(goal)
    return "Draft" if goal.started_at.blank?

    status = goal.progress_status
    title = PROGRESS_STATUS_COPY.fetch(status.to_sym)[:title]
    eh = EngagementHealth::GoalConfidence.status_for_goal(goal)
    return "#{title} · Stale check-in" if EngagementHealth::GoalConfidence.stale?(eh)

    title
  end

  def goals_bulk_edit_border_popover_content(goal)
    if goal.started_at.blank?
      return "Grey means this goal is still a draft (not started). Setting confidence creates a check-in and starts the goal."
    end

    status = goal.progress_status
    parts = [PROGRESS_STATUS_COPY.fetch(status.to_sym)[:body]]
    eh = EngagementHealth::GoalConfidence.status_for_goal(goal)
    if EngagementHealth::GoalConfidence.stale?(eh)
      healthy = EngagementHealth::Thresholds::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS
      needs = EngagementHealth::Thresholds::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS
      eh_label = EngagementHealth::STATUS_LABELS.fetch(eh)
      parts << "The diagonal pattern means Goal Confidence is #{eh_label} (Gruuv Health: healthy within #{healthy} days; needs attention at #{needs}+ days or never)."
    end
    parts.join(" ")
  end

  def goals_bulk_edit_owner_value(goal)
    type = goal.owner_type == "Organization" ? "Company" : goal.owner_type
    "#{type}_#{goal.owner_id}"
  end

  PRIVACY_LEVEL_OPTIONS = [
    ["Creator Only", "only_creator"],
    ["Creator & Owner", "only_creator_and_owner"],
    ["Creator, Owner & Managers", "only_creator_owner_and_managers"],
    ["Everyone in Company", "everyone_in_company"]
  ].freeze

  def goals_bulk_edit_goal_type_options
    GOAL_TYPE_OPTIONS
  end

  def goals_bulk_edit_privacy_level_options
    PRIVACY_LEVEL_OPTIONS
  end
end
