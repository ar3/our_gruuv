# frozen_string_literal: true

module Insights
  # Headline stats + week-over-week Team-owned goal activity for Teams Insights.
  class TeamsOverview
    Result = Struct.new(
      :teams_count,
      :average_members_per_team,
      :chart_data,
      keyword_init: true
    )

    def initialize(organization:, chart_range:)
      @organization = organization
      @chart_range = chart_range
    end

    def call
      teams = Team.for_company(@organization).active.includes(:team_members).to_a
      teams_count = teams.size
      member_total = teams.sum { |team| team.team_members.size }
      average = teams_count.zero? ? 0.0 : (member_total.to_f / teams_count).round(1)

      Result.new(
        teams_count: teams_count,
        average_members_per_team: average,
        chart_data: TeamsChartSeries.goal_activity_series(@chart_range, team_goals_scope)
      )
    end

    private

    def team_goals_scope
      Goal.where(company: @organization, owner_type: "Team", deleted_at: nil)
    end
  end
end
