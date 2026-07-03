# frozen_string_literal: true

module Insights
  module OgScorecard
    # Central registry of OG Scorecard metrics (metadata + defaults). Threshold values live in DB.
    class MetricRegistry
      Entry = Data.define(:key, :label, :direction, :supports_percent, :group, :threshold_hint, :separator)

      def self.metric(key:, label:, direction:, supports_percent:, group:, threshold_hint: nil)
        Entry.new(
          key: key,
          label: label,
          direction: direction,
          supports_percent: supports_percent,
          group: group,
          threshold_hint: threshold_hint,
          separator: false
        )
      end

      def self.separator(group:)
        Entry.new(
          key: nil,
          label: nil,
          direction: :more,
          supports_percent: false,
          group: group,
          threshold_hint: nil,
          separator: true
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
            when EngagementHealth::AT_RISK
              "last published #{t::OGO_HEALTHY_WITHIN_DAYS + 1}–#{t::OGO_NEEDS_ATTENTION_AT_DAYS - 1} days ago"
            when EngagementHealth::NEEDS_ATTENTION
              "last published ≥ #{t::OGO_NEEDS_ATTENTION_AT_DAYS} days ago or never"
            end
          when EngagementHealth::CATEGORY_GOAL_CONFIDENCE
            case status
            when EngagementHealth::HEALTHY
              "every in-scope goal checked ≤ #{t::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS} days ago"
            when EngagementHealth::AT_RISK
              "worst in-scope goal checked #{t::GOAL_CONFIDENCE_HEALTHY_WITHIN_DAYS + 1}–#{t::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS - 1} days ago"
            when EngagementHealth::NEEDS_ATTENTION
              "worst in-scope goal ≥ #{t::GOAL_CONFIDENCE_NEEDS_ATTENTION_AT_DAYS} days or never; or never started/completed a goal"
            end
          when EngagementHealth::CATEGORY_REQUIRED_CLARITY
            case status
            when EngagementHealth::HEALTHY
              "every required item finalized ≤ #{t::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS} days ago"
            when EngagementHealth::AT_RISK
              "worst required item #{t::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS + 1}–#{t::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS - 1} days ago"
            when EngagementHealth::NEEDS_ATTENTION
              "any required item ≥ #{t::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS} days ago or never"
            end
          when EngagementHealth::CATEGORY_MILESTONES
            case status
            when EngagementHealth::HEALTHY
              "required level earned or active goal on every required ability"
            when EngagementHealth::AT_RISK
              "earlier milestone or draft goal only on worst required ability"
            when EngagementHealth::NEEDS_ATTENTION
              "no milestone and no goal on any required ability"
            end
          end
        end

        def gruuv_health_entries(category:, metric_name:, group:)
          EngagementHealth::STATUSES.map do |status|
            status_label = EngagementHealth::STATUS_LABELS.fetch(status)
            Entry.new(
              key: GruuvHealthWeekCounts.metric_key(category, status),
              label: "Teammates that have #{status_label} #{metric_name}",
              direction: (status == EngagementHealth::HEALTHY ? :more : :less),
              supports_percent: true,
              group: group,
              threshold_hint: gruuv_threshold_hint(category, status),
              separator: false
            )
          end
        end

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
          separator(group: 'Observations'),
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
          separator(group: 'Observations')
        ] +
        gruuv_health_entries(category: EngagementHealth::CATEGORY_OGO_GIVEN, metric_name: 'OGOs Given', group: 'Observations') +
        [
          separator(group: 'Observations')
        ] +
        gruuv_health_entries(category: EngagementHealth::CATEGORY_OGO_RECEIVED, metric_name: 'OGOs Received', group: 'Observations') +
        [
          metric(
            key: 'unique_teammates_check_in_finalized_this_week',
            label: 'Teammates that had a check-in finalized this week',
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
          separator(group: 'Check-ins')
        ] +
        gruuv_health_entries(
          category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          metric_name: 'Required Clarity',
          group: 'Check-ins'
        ) +
        [
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
          separator(group: 'Ability Milestones'),
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
          separator(group: 'Ability Milestones')
        ] +
        gruuv_health_entries(
          category: EngagementHealth::CATEGORY_MILESTONES,
          metric_name: 'Milestones',
          group: 'Ability Milestones'
        ) +
        gruuv_health_entries(
          category: EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
          metric_name: 'Goal Confidence',
          group: 'Goals'
        ) +
        [
          separator(group: 'Goals'),
          metric(
            key: 'unique_teammates_active_goal',
            label: 'Teammates with an active goal',
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
          )
        ]
      ).freeze
    end
  end
end
