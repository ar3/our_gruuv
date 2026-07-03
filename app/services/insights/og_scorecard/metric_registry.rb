# frozen_string_literal: true

module Insights
  module OgScorecard
    # Central registry of OG Scorecard metrics (metadata + defaults). Threshold values live in DB.
    class MetricRegistry
      Entry = Data.define(:key, :label, :direction, :supports_percent, :group, :threshold_hint)

      CC = CheckInBehavior::CLARITY_CRYSTAL_CLEAR_DAYS
      C = CheckInBehavior::CLARITY_CLEAR_DAYS
      B = CheckInBehavior::CLARITY_BLURRED_DAYS

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
              threshold_hint: gruuv_threshold_hint(category, status)
            )
          end
        end

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
          Entry.new(
            key: 'active_teammates',
            label: 'Active teammates',
            direction: :more,
            supports_percent: true,
            group: 'Teammates',
            threshold_hint: nil
          )
        ] +
        gruuv_health_entries(category: EngagementHealth::CATEGORY_OGO_GIVEN, metric_name: 'OGOs Given', group: 'Observations') +
        gruuv_health_entries(category: EngagementHealth::CATEGORY_OGO_RECEIVED, metric_name: 'OGOs Received', group: 'Observations') +
        [
          Entry.new(
            key: 'unique_ogo_publishers',
            label: 'Teammates that published an OGO',
            direction: :more,
            supports_percent: true,
            group: 'Observations',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'unique_ogo_observees',
            label: 'Teammates named as observees in an OGO',
            direction: :more,
            supports_percent: true,
            group: 'Observations',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'unique_ogo_publishers_30_days',
            label: 'Teammates that published an OGO within 30 days of this week',
            direction: :more,
            supports_percent: true,
            group: 'Observations',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'unique_ogo_observees_30_days',
            label: 'Teammates mentioned in a published OGO within 30 days of this week',
            direction: :more,
            supports_percent: true,
            group: 'Observations',
            threshold_hint: nil
          )
        ] +
        gruuv_health_entries(
          category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          metric_name: 'Required Clarity',
          group: 'Check-ins'
        ) +
        [
          Entry.new(
            key: 'all_check_ins_clear',
            label: "Teammates with Healthy Clarity (checked-in within #{C} days)",
            direction: :more,
            supports_percent: true,
            group: 'Check-ins',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'all_check_ins_blurred',
            label: "Teammates with diminishing clarity (checked-in between #{C + 1}–#{B} days ago)",
            direction: :less,
            supports_percent: true,
            group: 'Check-ins',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'all_check_ins_obscured',
            label: "Teammates with a lack of clarity (at least one required check-in older than #{B} days ago)",
            direction: :less,
            supports_percent: true,
            group: 'Check-ins',
            threshold_hint: nil
          )
        ] +
        gruuv_health_entries(
          category: EngagementHealth::CATEGORY_MILESTONES,
          metric_name: 'Milestones',
          group: 'Ability Milestones'
        ) +
        [
          Entry.new(
            key: 'unique_teammates_milestone_this_week',
            label: 'Teammates with a milestone earned this week ' \
                   '(ability milestone attained in that Mon–Sun week, for abilities in this company)',
            direction: :more,
            supports_percent: true,
            group: 'Ability Milestones',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'milestones_earned_this_week',
            label: 'Number of milestones earned this week ' \
                   '(count of ability milestone records with attained_at in that Mon–Sun week)',
            direction: :more,
            supports_percent: false,
            group: 'Ability Milestones',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'unique_teammates_milestone_90_days',
            label: 'Teammates with a milestone earned within the past 90 days',
            direction: :more,
            supports_percent: true,
            group: 'Ability Milestones',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'milestones_earned_90_days',
            label: 'Milestones earned within the past 90 days',
            direction: :more,
            supports_percent: false,
            group: 'Ability Milestones',
            threshold_hint: nil
          )
        ] +
        gruuv_health_entries(
          category: EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
          metric_name: 'Goal Confidence',
          group: 'Goals'
        ) +
        [
          Entry.new(
            key: 'unique_teammates_active_goal',
            label: 'Teammates with an active goal',
            direction: :more,
            supports_percent: true,
            group: 'Goals',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'active_goal_aspiration',
            label: 'Teammates with an active goal attached to an Aspirational Value',
            direction: :more,
            supports_percent: true,
            group: 'Goals',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'active_goal_assignment',
            label: 'Teammates with an active goal attached to an Assignment',
            direction: :more,
            supports_percent: true,
            group: 'Goals',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'active_goal_ability',
            label: 'Teammates with an active goal attached to an Ability',
            direction: :more,
            supports_percent: true,
            group: 'Goals',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'unique_teammates_goal_check_in_this_week',
            label: 'Teammates with at least one goal confidence check-in this week',
            direction: :more,
            supports_percent: true,
            group: 'Goals',
            threshold_hint: nil
          ),
          Entry.new(
            key: 'unique_teammates_completed_goal_90_days',
            label: 'Teammates with a completed goal in the past 90 days',
            direction: :more,
            supports_percent: true,
            group: 'Goals',
            threshold_hint: nil
          )
        ]
      ).freeze
    end
  end
end
