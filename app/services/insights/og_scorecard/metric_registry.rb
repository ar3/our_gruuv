# frozen_string_literal: true

module Insights
  module OgScorecard
    # Central registry of OG Scorecard metrics (metadata + defaults). Threshold values live in DB.
    class MetricRegistry
      Entry = Data.define(:key, :label, :direction, :supports_percent, :group, :threshold_hint, :separator, :gruuv_status, :gruuv_category)

      def self.metric(key:, label:, direction:, supports_percent:, group:, threshold_hint: nil)
        Entry.new(
          key: key,
          label: label,
          direction: direction,
          supports_percent: supports_percent,
          group: group,
          threshold_hint: threshold_hint,
          separator: false,
          gruuv_status: nil,
          gruuv_category: nil
        )
      end

      def self.separator(group:, label: nil)
        Entry.new(
          key: nil,
          label: label,
          direction: :more,
          supports_percent: false,
          group: group,
          threshold_hint: nil,
          separator: true,
          gruuv_status: nil,
          gruuv_category: nil
        )
      end

      GROUP_ORDER = ['Teammates', 'Observations', 'Check-ins', 'Ability Milestones', 'Goals'].freeze

      class << self
        def gruuv_threshold_hint(category, status)
          t = EngagementHealth::Thresholds
          case category
          when EngagementHealth::CATEGORY_OGO_GIVEN, EngagementHealth::CATEGORY_OGO_RECEIVED
            case status
            when EngagementHealth::HEALTHY
              "last published ≤ #{t::OGO_HEALTHY_WITHIN_DAYS} days ago"
            when EngagementHealth::WARNING
              "last published #{t::OGO_HEALTHY_WITHIN_DAYS + 1}–#{t::OGO_NEEDS_ATTENTION_AT_DAYS - 1} days ago"
            when EngagementHealth::NEEDS_ATTENTION
              "last published ≥ #{t::OGO_NEEDS_ATTENTION_AT_DAYS} days ago or never"
            end
          when EngagementHealth::CATEGORY_GOAL_CONFIDENCE
            case status
            when EngagementHealth::HEALTHY
              "every in-scope goal checked ≤ #{t::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS} days ago"
            when EngagementHealth::WARNING
              "worst in-scope goal checked #{t::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS + 1}–#{t::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS - 1} days ago"
            when EngagementHealth::NEEDS_ATTENTION
              "worst in-scope goal ≥ #{t::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS} days or never; or never started/completed a goal"
            end
          when EngagementHealth::CATEGORY_REQUIRED_CLARITY
            case status
            when EngagementHealth::HEALTHY
              "every required item finalized ≤ #{t::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS} days ago"
            when EngagementHealth::WARNING
              "worst required item #{t::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS + 1}–#{t::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS - 1} days ago"
            when EngagementHealth::NEEDS_ATTENTION
              "any required item ≥ #{t::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS} days ago or never"
            end
          when EngagementHealth::CATEGORY_MILESTONES
            case status
            when EngagementHealth::HEALTHY
              "required level earned or active goal on every required ability"
            when EngagementHealth::WARNING
              "earlier milestone or draft goal only on worst required ability"
            when EngagementHealth::NEEDS_ATTENTION
              "no milestone and no goal on any required ability"
            end
          end
        end

        # Human-readable row label per category + status. Prose bakes in the live
        # day thresholds so the Healthy/Warning/Needs Attention jargon isn't needed
        # to understand the row. Kept MECE with EngagementHealth::Thresholds.
        def gruuv_health_label(category, status)
          t = EngagementHealth::Thresholds
          case category
          when EngagementHealth::CATEGORY_OGO_GIVEN
            ogo_label(status, "published an OGO")
          when EngagementHealth::CATEGORY_OGO_RECEIVED
            ogo_label(status, "been named in an OGO")
          when EngagementHealth::CATEGORY_REQUIRED_CLARITY
            h = t::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS
            na = t::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS
            case status
            when EngagementHealth::HEALTHY
              "Teammates that have finalized all their required check-in items in the last #{h} days"
            when EngagementHealth::WARNING
              "Teammates whose oldest required check-in item was finalized between #{h + 1} and #{na - 1} days ago"
            when EngagementHealth::NEEDS_ATTENTION
              "Teammates that have a required check-in item finalized #{na} or more days ago or never"
            end
          when EngagementHealth::CATEGORY_GOAL_CONFIDENCE
            h = t::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS
            na = t::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS
            case status
            when EngagementHealth::HEALTHY
              "Teammates that have checked confidence on all their active goals in the last #{h} days"
            when EngagementHealth::WARNING
              "Teammates whose oldest active-goal confidence check was between #{h + 1} and #{na - 1} days ago"
            when EngagementHealth::NEEDS_ATTENTION
              "Teammates that have an active goal not checked in #{na} or more days, or no started/completed goal"
            end
          when EngagementHealth::CATEGORY_MILESTONES
            case status
            when EngagementHealth::HEALTHY
              "Teammates that have earned the required level or an active goal on every required ability"
            when EngagementHealth::WARNING
              "Teammates that show signs of working towards their required ability milestones"
            when EngagementHealth::NEEDS_ATTENTION
              "Teammates that have no milestone and no goal on at least one required ability"
            end
          end
        end

        def gruuv_health_entries(category:, group:)
          EngagementHealth::STATUSES.map do |status|
            Entry.new(
              key: GruuvHealthWeekCounts.metric_key(category, status),
              label: gruuv_health_label(category, status),
              direction: (status == EngagementHealth::HEALTHY ? :more : :less),
              supports_percent: true,
              group: group,
              threshold_hint: gruuv_threshold_hint(category, status),
              separator: false,
              gruuv_status: status,
              gruuv_category: category
            )
          end
        end

        private

        # Shared prose for the two event-based OGO categories (given / received),
        # which use the same 30/90-day model.
        def ogo_label(status, verb)
          t = EngagementHealth::Thresholds
          h = t::OGO_HEALTHY_WITHIN_DAYS
          na = t::OGO_NEEDS_ATTENTION_AT_DAYS
          case status
          when EngagementHealth::HEALTHY
            "Teammates that have #{verb} in the last #{h} days"
          when EngagementHealth::WARNING
            "Teammates that have #{verb} between #{h + 1} and #{na - 1} days ago"
          when EngagementHealth::NEEDS_ATTENTION
            "Teammates that have either never #{verb} or last did so #{na} or more days ago"
          end
        end

        public

        def all
          ENTRIES
        end

        def keys
          ENTRIES.reject(&:separator).map(&:key)
        end

        def key?(key)
          keys.include?(key.to_s)
        end

        def find(key)
          ENTRIES.find { |e| !e.separator && e.key == key.to_s }
        end

        def grouped
          by_group = ENTRIES.group_by(&:group)
          GROUP_ORDER.filter_map do |title|
            entries = by_group[title]
            next if entries.blank?

            { title: title, entries: entries }
          end
        end
      end

      ENTRIES = (
        [
          metric(
            key: 'active_teammates',
            label: 'Active teammates',
            direction: :more,
            supports_percent: true,
            group: 'Teammates'
          )
        ] +
        [
          separator(group: 'Observations', label: 'Activity'),
          metric(
            key: 'unique_ogo_publishers_this_week',
            label: 'Teammates that published an OGO this week',
            direction: :more,
            supports_percent: true,
            group: 'Observations'
          ),
          metric(
            key: 'unique_ogo_publishers',
            label: 'Teammates that published an OGO all-time',
            direction: :more,
            supports_percent: true,
            group: 'Observations'
          ),
          metric(
            key: 'unique_ogo_observees_this_week',
            label: 'Teammates named as observees in an OGO this week',
            direction: :more,
            supports_percent: true,
            group: 'Observations'
          ),
          metric(
            key: 'unique_ogo_observees',
            label: 'Teammates named as observees in an OGO all-time',
            direction: :more,
            supports_percent: true,
            group: 'Observations'
          ),
          separator(group: 'Observations', label: 'Gruuv Health · OGOs Given')
        ] +
        gruuv_health_entries(category: EngagementHealth::CATEGORY_OGO_GIVEN, group: 'Observations') +
        [separator(group: 'Observations', label: 'Gruuv Health · OGOs Received')] +
        gruuv_health_entries(category: EngagementHealth::CATEGORY_OGO_RECEIVED, group: 'Observations') +
        [
          separator(group: 'Check-ins', label: 'Activity'),
          metric(
            key: 'unique_teammates_check_in_finalized_this_week',
            label: 'Teammates that had a check-in finalized this week',
            direction: :more,
            supports_percent: true,
            group: 'Check-ins'
          ),
          metric(
            key: 'unique_teammates_check_in_finalized_90_days',
            label: 'Teammates with a check-in finalized within the past 90 days',
            direction: :more,
            supports_percent: true,
            group: 'Check-ins'
          ),
          metric(
            key: 'unique_teammates_position_check_in_finalized_90_days',
            label: 'Teammates with a finalized position check-in within the past 90 days',
            direction: :more,
            supports_percent: true,
            group: 'Check-ins'
          ),
          metric(
            key: 'unique_teammates_check_in_finalized_all_time',
            label: 'Teammates that have had a check-in finalized all-time',
            direction: :more,
            supports_percent: true,
            group: 'Check-ins'
          ),
          separator(group: 'Check-ins', label: 'Gruuv Health · Required Clarity Check-Ins')
        ] +
        gruuv_health_entries(
          category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          group: 'Check-ins'
        ) +
        [
          separator(group: 'Ability Milestones', label: 'Activity'),
          metric(
            key: 'milestones_earned_this_week',
            label: 'Milestones earned this week',
            direction: :more,
            supports_percent: false,
            group: 'Ability Milestones'
          ),
          metric(
            key: 'milestones_earned_90_days',
            label: 'Milestones earned within the past 90 days',
            direction: :more,
            supports_percent: false,
            group: 'Ability Milestones'
          ),
          metric(
            key: 'milestones_earned_all_time',
            label: 'Milestones earned all-time',
            direction: :more,
            supports_percent: false,
            group: 'Ability Milestones'
          ),
          metric(
            key: 'unique_teammates_milestone_this_week',
            label: 'Teammates with a milestone earned this week',
            direction: :more,
            supports_percent: true,
            group: 'Ability Milestones'
          ),
          metric(
            key: 'unique_teammates_milestone_90_days',
            label: 'Teammates with a milestone earned within the past 90 days',
            direction: :more,
            supports_percent: true,
            group: 'Ability Milestones'
          ),
          metric(
            key: 'unique_teammates_milestone_all_time',
            label: 'Teammates with a milestone earned all-time',
            direction: :more,
            supports_percent: true,
            group: 'Ability Milestones'
          ),
          separator(group: 'Ability Milestones', label: 'Gruuv Health · Milestones')
        ] +
        gruuv_health_entries(
          category: EngagementHealth::CATEGORY_MILESTONES,
          group: 'Ability Milestones'
        ) +
        [
          separator(group: 'Goals', label: 'Activity'),
          metric(
            key: 'unique_teammates_active_goal',
            label: 'Teammates with an active goal',
            direction: :more,
            supports_percent: true,
            group: 'Goals'
          ),
          metric(
            key: 'unique_teammates_active_goal_90_days',
            label: 'Teammates that have had an active goal at some point in the last 90 days',
            direction: :more,
            supports_percent: true,
            group: 'Goals'
          ),
          metric(
            key: 'active_goal_aspiration',
            label: 'Teammates with an active goal attached to an Aspirational Value',
            direction: :more,
            supports_percent: true,
            group: 'Goals'
          ),
          metric(
            key: 'active_goal_assignment',
            label: 'Teammates with an active goal attached to an Assignment',
            direction: :more,
            supports_percent: true,
            group: 'Goals'
          ),
          metric(
            key: 'active_goal_ability',
            label: 'Teammates with an active goal attached to an Ability',
            direction: :more,
            supports_percent: true,
            group: 'Goals'
          ),
          metric(
            key: 'unique_teammates_goal_check_in_this_week',
            label: 'Teammates with at least one goal confidence check-in this week',
            direction: :more,
            supports_percent: true,
            group: 'Goals'
          ),
          metric(
            key: 'unique_teammates_completed_goal_90_days',
            label: 'Teammates with a completed goal in the past 90 days',
            direction: :more,
            supports_percent: true,
            group: 'Goals'
          ),
          separator(group: 'Goals', label: 'Gruuv Health · Goal Confidence')
        ] +
        gruuv_health_entries(
          category: EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
          group: 'Goals'
        )
      ).freeze
    end
  end
end
