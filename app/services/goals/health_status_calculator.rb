# frozen_string_literal: true

module Goals
  class HealthStatusCalculator
    def self.call(goals)
      new(goals).call
    end

    def initialize(goals)
      @goals = Array(goals)
    end

    def call
      return :concerning if active_goals.empty? && !completed_recently?
      return :healthy if completed_recently? || all_active_goals_have_recent_check_ins?

      :ok
    end

    private

    attr_reader :goals

    def completed_recently?
      goals.any? do |goal|
        goal.deleted_at.nil? &&
          goal.completed_at.present? &&
          goal.completed_at >= Goals::HealthThresholds.completed_recently_cutoff
      end
    end

    def active_goals
      @active_goals ||= goals.select { |goal| goal.deleted_at.nil? && goal.completed_at.nil? && goal.started_at.present? }
    end

    def all_active_goals_have_recent_check_ins?
      return false if active_goals.empty?

      cutoff_week = Goals::HealthThresholds.check_in_recency_cutoff_week_start
      active_goals.all? do |goal|
        goal.goal_check_ins.any? { |check_in| check_in.check_in_week_start >= cutoff_week }
      end
    end
  end
end
