# frozen_string_literal: true

module Goals
  # Builds Highcharts-ready data for the goal confidence progress chart (area ranges + actual check-ins).
  # Returns nil if goal has no target dates or no started_at.
  # Area bands: below behind = red, behind–on = yellow, on–ahead = light green, above ahead = dark green.
  class ProgressChartDataBuilder
    def self.call(goal:) = new(goal: goal).call

    def initialize(goal:)
      @goal = goal
    end

    def call
      return nil if chart_end_date.nil? || @goal.started_at.nil?

      # Start the area chart the Monday after the start date so we never go back in time
      start_monday = first_monday_after(@goal.started_at.to_date)
      mondays = mondays_from(start_monday, chart_end_date)

      calculator = Goals::GoalProgressStatusConfidenceRangeCalculator
      # Stacked area bands (bottom to top): red 0→behind, yellow behind→on, light_green on→ahead, dark_green ahead→100
      red_band = []
      yellow_band = []
      light_green_band = []
      dark_green_band = []
      thresholds_table = []
      mondays.each do |monday|
        ranges = calculator.call(
          initial_confidence: @goal.initial_confidence&.to_sym || :stretch,
          earliest_target_date: @goal.earliest_target_date || @goal.most_likely_target_date,
          latest_target_date: @goal.latest_target_date || @goal.most_likely_target_date,
          most_likely_target_date: @goal.most_likely_target_date,
          started_at: @goal.started_at,
          progress_check_date: monday
        )
        next unless ranges

        behind = ranges[:behind_schedule_if_confidence_below].to_f
        on = ranges[:on_schedule_if_confidence_above].to_f
        ahead = ranges[:ahead_of_schedule_if_confidence_above].to_f
        ts = monday.to_time.utc.to_i * 1000
        red_band << [ts, behind]
        yellow_band << [ts, on - behind]
        light_green_band << [ts, ahead - on]
        dark_green_band << [ts, 100 - ahead]
        check_in = @goal.goal_check_ins.find_by(check_in_week_start: monday)
        thresholds_table << {
          week: monday.strftime('%b %d'),
          behind_schedule_if_confidence_below: behind.round,
          ahead_of_schedule_if_confidence_above: ahead.round,
          on_schedule_if_confidence_above: on.round,
          check_in_confidence: check_in&.confidence_percentage
        }
      end

      check_in_points = @goal.goal_check_ins.order(check_in_week_start: :asc).map do |c|
        [c.check_in_week_start.to_time.utc.to_i * 1000, c.confidence_percentage.to_i]
      end

      {
        categories: mondays.map { |m| m.strftime('%b %d') },
        thresholds_table: thresholds_table,
        # Area series order: first in array stacks at bottom in Highcharts. We want red at bottom, dark green on top.
        series: [
          { name: 'Ahead of schedule', data: dark_green_band, color: '#198754', type: 'area', stack: 'thresholds' },
          { name: 'Ahead band', data: light_green_band, color: '#a3cfbb', type: 'area', stack: 'thresholds' },
          { name: 'On schedule band', data: yellow_band, color: '#ffc107', type: 'area', stack: 'thresholds' },
          { name: 'Behind schedule', data: red_band, color: '#dc3545', type: 'area', stack: 'thresholds' },
          { name: 'Actual confidence', data: check_in_points, type: 'scatter', color: '#0d6efd', marker: { radius: 6 } }
        ]
      }
    end

    private

    # End chart on the Monday of the week following the latest target date
    def chart_end_date
      max_target = [@goal.latest_target_date, @goal.most_likely_target_date, @goal.earliest_target_date].compact.max
      return nil if max_target.nil?

      monday_of_week_following(max_target.to_date)
    end

    # Monday of the week following the week that contains date
    def monday_of_week_following(date)
      date.monday? ? date + 7 : date + (8 - date.wday) % 7
    end

    # First Monday strictly after the given date (so the chart never goes back in time)
    def first_monday_after(date)
      d = date + 1
      d.monday? ? d : d + (8 - d.wday) % 7
    end

    def mondays_from(start_monday, end_date)
      return [] if end_date.nil? || start_monday > end_date

      mondays = []
      current = start_monday
      while current <= end_date
        mondays << current
        current = current + 1.week
      end
      mondays
    end
  end
end
