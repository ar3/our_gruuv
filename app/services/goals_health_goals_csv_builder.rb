# frozen_string_literal: true

require "csv"

class GoalsHealthGoalsCsvBuilder
  def initialize(organization, visible_goals_by_teammate, bucket_lookup: nil)
    @organization = organization
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

  attr_reader :organization, :visible_goals_by_teammate, :bucket_lookup

  def headers
    [
      "Employee Name",
      "Employee Email",
      "Manager Name",
      "Goal Creator",
      "Goal Created At",
      "Goal Title",
      "Goal Status",
      "Group",
      "Privacy Level",
      "Goal Type",
      "Started At",
      "Completed At",
      "Latest Check-in Week Start",
      "Latest Check-in Confidence %"
    ]
  end

  def rows
    out = []
    lookup = bucket_lookup || Goals::HealthGoalBucketLookup.load_for_goal_ids(visible_goals_by_teammate.values.flatten.map(&:id))
    visible_goals_by_teammate.each do |teammate, goals|
      manager = Goals::HealthManagerPerson.for(teammate)
      child_goal_ids = lookup.child_goal_ids
      associated_goal_ids = lookup.associated_goal_ids

      goals.each do |goal|
        latest_check_in = goal.goal_check_ins.max_by(&:check_in_week_start)
        out << [
          teammate.person&.display_name.to_s,
          teammate.person&.email.to_s,
          manager&.display_name.to_s,
          goal.creator&.person&.display_name.to_s,
          datetime(goal.created_at),
          goal.title.to_s,
          goal_status(goal),
          goal_group(goal, child_goal_ids, associated_goal_ids),
          goal.privacy_level.to_s,
          goal.goal_type.to_s,
          date_only(goal.started_at),
          date_only(goal.completed_at),
          latest_check_in&.check_in_week_start&.to_s.to_s,
          latest_check_in&.confidence_percentage.to_s
        ]
      end
    end
    out
  end

  def goal_group(goal, child_goal_ids, associated_goal_ids)
    return "Child-goals" if child_goal_ids.include?(goal.id)
    return "Top-level & associated" if associated_goal_ids.include?(goal.id)

    "Top-level & unassociated"
  end

  def goal_status(goal)
    return "completed" if goal.completed_at.present?
    return "active" if goal.started_at.present?

    "draft"
  end

  def date_only(value)
    return "" if value.blank?

    value.to_date.iso8601
  end

  def datetime(value)
    return "" if value.blank?

    value.respond_to?(:strftime) ? value.strftime("%Y-%m-%d %H:%M") : value.to_s
  end
end
