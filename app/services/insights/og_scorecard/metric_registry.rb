# frozen_string_literal: true

module Insights
  module OgScorecard
    # Central registry of OG Scorecard metrics (metadata + defaults). Threshold values live in DB.
    class MetricRegistry
      Entry = Data.define(:key, :label, :direction, :supports_percent, :group)

      CC = CheckInBehavior::CLARITY_CRYSTAL_CLEAR_DAYS
      C = CheckInBehavior::CLARITY_CLEAR_DAYS
      B = CheckInBehavior::CLARITY_BLURRED_DAYS

      ENTRIES = [
        Entry.new(
          key: 'active_teammates',
          label: 'Number of active teammates',
          direction: :more,
          supports_percent: true,
          group: 'Teammates'
        ),
        Entry.new(
          key: 'unique_ogo_publishers',
          label: 'Number of unique teammates that published an OGO',
          direction: :more,
          supports_percent: true,
          group: 'Observations'
        ),
        Entry.new(
          key: 'unique_ogo_observees',
          label: 'Number of unique teammates named as observees in an OGO',
          direction: :more,
          supports_percent: true,
          group: 'Observations'
        ),
        Entry.new(
          key: 'all_check_ins_clear',
          label: "Number of unique teammates with all required check-ins within #{C} days",
          direction: :more,
          supports_percent: true,
          group: 'Check-ins'
        ),
        Entry.new(
          key: 'all_check_ins_blurred',
          label: "Number of unique teammates with at least one required check-in between #{C + 1}–#{B} days",
          direction: :less,
          supports_percent: true,
          group: 'Check-ins'
        ),
        Entry.new(
          key: 'all_check_ins_obscured',
          label: "Number of unique teammates with at least one required check-in older than #{B} days",
          direction: :less,
          supports_percent: true,
          group: 'Check-ins'
        ),
        Entry.new(
          key: 'unique_teammates_milestone_this_week',
          label: 'Number of unique teammates with a milestone earned this week ' \
                 '(ability milestone attained in that Mon–Sun week, for abilities in this company)',
          direction: :more,
          supports_percent: true,
          group: 'Ability Milestones'
        ),
        Entry.new(
          key: 'milestones_earned_this_week',
          label: 'Number of milestones earned this week ' \
                 '(count of ability milestone records with attained_at in that Mon–Sun week)',
          direction: :more,
          supports_percent: false,
          group: 'Ability Milestones'
        ),
        Entry.new(
          key: 'unique_teammates_milestone_90_days',
          label: 'Number of unique teammates with a milestone earned within the past 90 days ' \
                 '(rolling 90 calendar days ending that Sunday, for abilities in this company)',
          direction: :more,
          supports_percent: true,
          group: 'Ability Milestones'
        ),
        Entry.new(
          key: 'milestones_earned_90_days',
          label: 'Number of milestones earned within the past 90 days ' \
                 '(count of ability milestone records in the rolling 90-day window ending that Sunday)',
          direction: :more,
          supports_percent: false,
          group: 'Ability Milestones'
        ),
        Entry.new(
          key: 'unique_teammates_active_goal',
          label: 'Number of unique teammates with an active goal ' \
                 '(goal owned by the teammate, started, not completed or deleted as of that Sunday)',
          direction: :more,
          supports_percent: true,
          group: 'Goals'
        ),
        Entry.new(
          key: 'active_goal_aspiration',
          label: 'Number of unique teammates with an active goal attached to an Aspirational Value',
          direction: :more,
          supports_percent: true,
          group: 'Goals'
        ),
        Entry.new(
          key: 'active_goal_assignment',
          label: 'Number of unique teammates with an active goal attached to an Assignment',
          direction: :more,
          supports_percent: true,
          group: 'Goals'
        ),
        Entry.new(
          key: 'active_goal_ability',
          label: 'Number of unique teammates with an active goal attached to an Ability ' \
                 '(goal owned by the teammate, started, not completed or deleted as of that Sunday, with a goal link to an ability)',
          direction: :more,
          supports_percent: true,
          group: 'Goals'
        ),
        Entry.new(
          key: 'unique_teammates_goal_check_in_this_week',
          label: 'Number of unique teammates with at least one goal check-in this week ' \
                 '(a GoalCheckIn created during that Mon–Sun week on an active owned goal as of that Sunday)',
          direction: :more,
          supports_percent: true,
          group: 'Goals'
        ),
        Entry.new(
          key: 'unique_teammates_completed_goal_90_days',
          label: 'Number of unique teammates with a completed goal in the past 90 days ' \
                 '(rolling 90 calendar days ending that Sunday; goal owned by the teammate with completed_at in that window)',
          direction: :more,
          supports_percent: true,
          group: 'Goals'
        )
      ].freeze

      class << self
        def all
          ENTRIES
        end

        def keys
          ENTRIES.map(&:key)
        end

        def key?(key)
          keys.include?(key.to_s)
        end

        def find(key)
          ENTRIES.find { |e| e.key == key.to_s }
        end

        def grouped
          ENTRIES.group_by(&:group).map { |title, rows| { title: title, entries: rows } }
        end
      end
    end
  end
end
