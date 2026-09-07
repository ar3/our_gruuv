# frozen_string_literal: true

module TeamsHealth
  # Org-level Team Goal Confidence summary. Each active team is scored with
  # the same Engagement Health Goal Confidence rules as a teammate, using
  # Team-owned goals only. Empty / drafts-only → Needs Attention.
  class Summary
    Result = Struct.new(
      :total_teams,
      :healthy_count,
      :warning_count,
      :needs_attention_count,
      :healthy_pct,
      :needs_attention_pct,
      keyword_init: true
    )

    def initialize(organization:, reference_time: Time.current)
      @organization = organization
      @reference_time = reference_time
    end

    def call
      teams = Team.for_company(@organization).active.ordered.to_a
      goals_by_team_id = EngagementHealth::GoalConfidence
        .scorable_goals_for_owners(
          owner_type: "Team",
          owner_ids: teams.map(&:id),
          reference_time: @reference_time
        )
        .group_by(&:owner_id)

      counts = {
        EngagementHealth::HEALTHY => 0,
        EngagementHealth::WARNING => 0,
        EngagementHealth::NEEDS_ATTENTION => 0
      }

      teams.each do |team|
        rollup = EngagementHealth::GoalConfidence.rollup_status(
          Array(goals_by_team_id[team.id]),
          reference_time: @reference_time
        )
        counts[rollup[:status]] += 1
      end

      total = teams.size
      needs_attention = counts[EngagementHealth::NEEDS_ATTENTION]
      healthy = counts[EngagementHealth::HEALTHY]

      Result.new(
        total_teams: total,
        healthy_count: healthy,
        warning_count: counts[EngagementHealth::WARNING],
        needs_attention_count: needs_attention,
        healthy_pct: percent(healthy, total),
        needs_attention_pct: percent(needs_attention, total)
      )
    end

    private

    def percent(part, total)
      return 0 if total.zero?

      ((part.to_f / total) * 100).round
    end
  end
end
