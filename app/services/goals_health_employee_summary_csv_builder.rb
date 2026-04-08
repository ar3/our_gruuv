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
      "Top-level & associated Active Count",
      "Top-level & associated Completed Count",
      "Top-level & unassociated Status",
      "Top-level & unassociated Draft Count",
      "Top-level & unassociated Active Count",
      "Top-level & unassociated Completed Count",
      "Child-goals Status",
      "Child-goals Draft Count",
      "Child-goals Active Count",
      "Child-goals Completed Count"
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
        buckets[:associated][:active],
        buckets[:associated][:completed],
        buckets[:unassociated][:status].to_s,
        buckets[:unassociated][:draft],
        buckets[:unassociated][:active],
        buckets[:unassociated][:completed],
        buckets[:child][:status].to_s,
        buckets[:child][:draft],
        buckets[:child][:active],
        buckets[:child][:completed]
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
    {
      status: Goals::HealthStatusCalculator.call(goals),
      draft: goals.count { |goal| goal.completed_at.nil? && goal.started_at.nil? },
      active: goals.count { |goal| goal.completed_at.nil? && goal.started_at.present? },
      completed: goals.count { |goal| goal.completed_at.present? }
    }
  end
end
