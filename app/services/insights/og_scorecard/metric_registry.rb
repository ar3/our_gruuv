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
          label: "Number of unique teammates with all required check-ins at least clear " \
                 "(each required position, assignment, and company aspirational value check-in is clear or crystal clear " \
                 "as of that Sunday—crystal clear: finalized within #{CC} days; clear: #{CC + 1}–#{C} days; " \
                 "teammates with no required check-ins count as clear)",
          direction: :more,
          supports_percent: true,
          group: 'Check-ins'
        ),
        Entry.new(
          key: 'all_check_ins_blurred',
          label: "Number of unique teammates with at least one required check-in blurred " \
                 "(at least one required check-in is blurred—finalized #{C + 1}–#{B} days before that Sunday—and none are obscured)",
          direction: :less,
          supports_percent: true,
          group: 'Check-ins'
        ),
        Entry.new(
          key: 'all_check_ins_obscured',
          label: "Number of unique teammates with at least one required check-in obscured " \
                 "(at least one required check-in is obscured—no finalization within #{B} days before that Sunday)",
          direction: :less,
          supports_percent: true,
          group: 'Check-ins'
        ),
        Entry.new(
          key: 'active_goal_aspiration',
          label: 'Number of unique teammates with an active goal attached to an Aspirational Value ' \
                 '(goal owned by the teammate, started, not completed or deleted as of that Sunday, with a goal link to an aspiration)',
          direction: :more,
          supports_percent: true,
          group: 'Check-ins'
        ),
        Entry.new(
          key: 'active_goal_assignment',
          label: 'Number of unique teammates with an active goal attached to an Assignment ' \
                 '(goal owned by the teammate, started, not completed or deleted as of that Sunday, with a goal link to an assignment)',
          direction: :more,
          supports_percent: true,
          group: 'Check-ins'
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
