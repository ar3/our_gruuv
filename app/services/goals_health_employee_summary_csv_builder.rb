# frozen_string_literal: true

require "csv"

class GoalsHealthEmployeeSummaryCsvBuilder
  HEALTHY_DAYS = EngagementHealth::Thresholds::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS
  COMPLETED_WINDOW_DAYS = EngagementHealth::Thresholds::COMPLETED_GOAL_WINDOW_DAYS

  def initialize(visible_goals_by_teammate, organization: nil)
    @visible_goals_by_teammate = visible_goals_by_teammate
    @organization = organization
  end

  def call
    CSV.generate(headers: true) do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
  end

  private

  attr_reader :visible_goals_by_teammate, :organization

  def headers
    [
      "Employee Name",
      "Employee Email",
      "Manager Name",
      "Manager Email",
      "Goal Confidence Status",
      "Draft Count",
      "Active Count",
      "Active (Healthy) Count",
      "Active (not Healthy) Count",
      "Completed Count",
      "Completed in last #{COMPLETED_WINDOW_DAYS} days Count",
      "Completed more than #{COMPLETED_WINDOW_DAYS} days ago Count",
      "In-scope Goal Count"
    ]
  end

  def rows
    org = organization || visible_goals_by_teammate.keys.first&.organization
    records_by_teammate_id = if org
      GoalsHealthEngagementHealthSupport.records_by_teammate_id(
        organization: org,
        teammate_ids: visible_goals_by_teammate.keys.map(&:id)
      )
    else
      {}
    end

    visible_goals_by_teammate.map do |teammate, goals|
      manager = Goals::HealthManagerPerson.for(teammate)
      records = records_by_teammate_id[teammate.id] || []
      counts = goal_counts(goals)
      [
        teammate.person&.display_name.to_s,
        teammate.person&.email.to_s,
        manager&.display_name.to_s,
        manager&.email.to_s,
        status_label(GoalsHealthEngagementHealthSupport.category_status(records)),
        counts[:draft],
        counts[:active],
        counts[:active_healthy],
        counts[:active_not_healthy],
        counts[:completed],
        counts[:completed_recent],
        counts[:completed_older],
        GoalsHealthEngagementHealthSupport.items_for(records).size
      ]
    end
  end

  def goal_counts(goals)
    healthy_cutoff = HEALTHY_DAYS.days.ago
    completed_cutoff = COMPLETED_WINDOW_DAYS.days.ago
    active_goals = goals.select { |goal| goal.completed_at.nil? && goal.started_at.present? }
    active_healthy = active_goals.count { |goal| active_goal_healthy?(goal, healthy_cutoff) }
    completed_goals = goals.select { |goal| goal.completed_at.present? }
    completed_recent = completed_goals.count { |goal| goal.completed_at && goal.completed_at >= completed_cutoff }

    {
      draft: goals.count { |goal| goal.completed_at.nil? && goal.started_at.nil? },
      active: active_goals.count,
      active_healthy: active_healthy,
      active_not_healthy: active_goals.count - active_healthy,
      completed: completed_goals.count,
      completed_recent: completed_recent,
      completed_older: completed_goals.count - completed_recent
    }
  end

  def active_goal_healthy?(goal, healthy_cutoff)
    latest_check_in = goal.goal_check_ins.max_by(&:updated_at)
    latest_check_in&.updated_at.present? && latest_check_in.updated_at >= healthy_cutoff
  end

  def status_label(status)
    EngagementHealth::STATUS_LABELS.fetch(status.to_s) { status.to_s }
  end
end
