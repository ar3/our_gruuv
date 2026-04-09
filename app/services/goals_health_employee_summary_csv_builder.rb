# frozen_string_literal: true

require "csv"

class GoalsHealthEmployeeSummaryCsvBuilder
  def initialize(visible_goals_by_teammate, bucket_lookup: nil)
    @visible_goals_by_teammate = visible_goals_by_teammate
    @bucket_lookup = bucket_lookup
  end

  def call
    CSV.generate(headers: true) do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
  end

  private

  attr_reader :visible_goals_by_teammate, :bucket_lookup

  def headers
    [
      "Employee Name",
      "Employee Email",
      "Manager Name",
      "Manager Email",
      "Overall Status",
      "Top-level & associated Status",
      "Top-level & associated Draft Count",
      "Top-level & associated Active (no recent check-in) Count",
      "Top-level & associated Active (recent check-in) Count",
      "Top-level & associated Completed in last 90 days Count",
      "Top-level & associated Completed more than 90 days ago Count",
      "Top-level & unassociated Status",
      "Top-level & unassociated Draft Count",
      "Top-level & unassociated Active (no recent check-in) Count",
      "Top-level & unassociated Active (recent check-in) Count",
      "Top-level & unassociated Completed in last 90 days Count",
      "Top-level & unassociated Completed more than 90 days ago Count",
      "Child-goals Status",
      "Child-goals Draft Count",
      "Child-goals Active (no recent check-in) Count",
      "Child-goals Active (recent check-in) Count",
      "Child-goals Completed in last 90 days Count",
      "Child-goals Completed more than 90 days ago Count"
    ]
  end

  def rows
    lookup = bucket_lookup || Goals::HealthGoalBucketLookup.load_for_goal_ids(visible_goals_by_teammate.values.flatten.map(&:id))
    visible_goals_by_teammate.map do |teammate, goals|
      manager = Goals::HealthManagerPerson.for(teammate)
      buckets = bucketed_counts(goals, lookup)
      [
        teammate.person&.display_name.to_s,
        teammate.person&.email.to_s,
        manager&.display_name.to_s,
        manager&.email.to_s,
        Goals::HealthStatusCalculator.call(goals).to_s,
        buckets[:associated][:status].to_s,
        buckets[:associated][:draft],
        buckets[:associated][:active_no_recent_check_in],
        buckets[:associated][:active_recent_check_in],
        buckets[:associated][:completed_recent],
        buckets[:associated][:completed_older],
        buckets[:unassociated][:status].to_s,
        buckets[:unassociated][:draft],
        buckets[:unassociated][:active_no_recent_check_in],
        buckets[:unassociated][:active_recent_check_in],
        buckets[:unassociated][:completed_recent],
        buckets[:unassociated][:completed_older],
        buckets[:child][:status].to_s,
        buckets[:child][:draft],
        buckets[:child][:active_no_recent_check_in],
        buckets[:child][:active_recent_check_in],
        buckets[:child][:completed_recent],
        buckets[:child][:completed_older]
      ]
    end
  end

  def bucketed_counts(goals, lookup)
    buckets = lookup.partition(goals)
    {
      associated: status_and_counts(buckets[:associated]),
      unassociated: status_and_counts(buckets[:unassociated]),
      child: status_and_counts(buckets[:child])
    }
  end

  def status_and_counts(goals)
    active_cutoff_week = Goals::HealthThresholds.check_in_recency_cutoff_week_start
    completed_cutoff = Goals::HealthThresholds.completed_recently_cutoff
    active_goals = goals.select { |goal| goal.completed_at.nil? && goal.started_at.present? }
    active_recent = active_goals.count { |goal| active_goal_has_recent_check_in?(goal, active_cutoff_week) }
    completed_goals = goals.select { |goal| goal.completed_at.present? }
    completed_recent = completed_goals.count { |goal| goal.completed_at && goal.completed_at >= completed_cutoff }

    {
      status: Goals::HealthStatusCalculator.call(goals),
      draft: goals.count { |goal| goal.completed_at.nil? && goal.started_at.nil? },
      active_no_recent_check_in: active_goals.count - active_recent,
      active_recent_check_in: active_recent,
      completed_recent: completed_recent,
      completed_older: completed_goals.count - completed_recent
    }
  end

  def active_goal_has_recent_check_in?(goal, cutoff_week)
    latest_check_in = goal.goal_check_ins.max_by(&:check_in_week_start)
    latest_check_in&.check_in_week_start.present? && latest_check_in.check_in_week_start >= cutoff_week
  end
end
