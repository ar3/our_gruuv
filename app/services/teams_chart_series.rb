# frozen_string_literal: true

# Week-over-week Team-owned goal activity for Teams Insights.
class TeamsChartSeries
  def self.goal_activity_series(chart_range, goals_scope)
    week_dates, categories = week_axis(chart_range)
    chart_end = chart_range.end.end_of_day

    goals = goals_scope
      .where("created_at <= ?", chart_end)
      .includes(:goal_check_ins)
      .to_a

    started_data = []
    confidence_checked_data = []
    stale_data = []
    completed_data = []

    week_dates.each do |w|
      week_start_time = w.to_time.beginning_of_day
      week_end_time = (w + 6.days).to_time.end_of_day

      started_data << goals.count do |goal|
        goal.started_at.present? &&
          goal.started_at >= week_start_time &&
          goal.started_at <= week_end_time
      end

      confidence_checked_data << goals.count do |goal|
        goal.goal_check_ins.any? do |check_in|
          check_in.updated_at >= week_start_time && check_in.updated_at <= week_end_time
        end
      end

      completed_data << goals.count do |goal|
        goal.completed_at.present? &&
          goal.completed_at >= week_start_time &&
          goal.completed_at <= week_end_time
      end

      # Point-in-time stock: scorable Team goals that are Warning or Needs Attention at week end.
      stale_data << stale_count_at(goals, week_end_time)
    end

    {
      categories: categories,
      series: [
        { name: "Started", data: started_data },
        { name: "Confidence checked", data: confidence_checked_data },
        { name: "Stale (Warning + Needs Attention)", data: stale_data },
        { name: "Completed", data: completed_data }
      ]
    }
  end

  def self.stale_count_at(goals, reference_time)
    window_start = reference_time - EngagementHealth::Thresholds::COMPLETED_GOAL_WINDOW_DAYS.days
    scorable = goals.select do |goal|
      next false if goal.created_at > reference_time
      next false if goal.deleted_at.present? && goal.deleted_at <= reference_time

      active = goal.started_at.present? &&
        goal.started_at <= reference_time &&
        (goal.completed_at.nil? || goal.completed_at > reference_time)
      recently_completed = goal.completed_at.present? &&
        goal.completed_at >= window_start &&
        goal.completed_at <= reference_time
      active || recently_completed
    end

    scorable.count do |goal|
      status = EngagementHealth::GoalConfidence.status_for_goal(goal, reference_time: reference_time)
      EngagementHealth::GoalConfidence.stale?(status)
    end
  end
  private_class_method :stale_count_at

  def self.week_axis(chart_range)
    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime("%b %d, %Y") }
    [week_dates, categories]
  end
  private_class_method :week_axis
end
