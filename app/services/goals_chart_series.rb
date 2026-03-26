# Weekly goal chart data for Insights and My Growth (owner-scoped).
class GoalsChartSeries
  def self.goals_base_scope(company)
    Goal.where(company: company).where(deleted_at: nil)
  end

  # Stacked column: started, check-in, ongoing no check-in, completed (same logic as Insights).
  def self.stacked_series(chart_range, goals_scope)
    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }

    started_data = []
    check_in_data = []
    ongoing_no_check_in_data = []
    completed_data = []

    week_dates.each do |w|
      week_end_d = w + 6.days
      week_end_time = week_end_d.to_time.end_of_day
      week_start_time = w.to_time.beginning_of_day

      completed_ids = goals_scope
        .where(completed_at: week_start_time..week_end_time)
        .pluck(:id)

      started_ids = goals_scope
        .where(started_at: week_start_time..week_end_time)
        .where.not(id: completed_ids)
        .pluck(:id)

      goal_ids_with_check_in_this_week = GoalCheckIn.where(check_in_week_start: w).pluck(:goal_id).uniq
      check_in_ids = goals_scope
        .where(id: goal_ids_with_check_in_this_week)
        .where.not(id: completed_ids + started_ids)
        .where('started_at < ?', week_start_time)
        .pluck(:id)

      ongoing_ids = goals_scope
        .where.not(started_at: nil)
        .where('started_at < ?', week_start_time)
        .where('completed_at IS NULL OR completed_at > ?', week_end_time)
        .where.not(id: GoalCheckIn.where(check_in_week_start: w).select(:goal_id))
        .pluck(:id)
      ongoing_ids = ongoing_ids - completed_ids - started_ids - check_in_ids

      started_data << started_ids.size
      check_in_data << check_in_ids.size
      ongoing_no_check_in_data << ongoing_ids.size
      completed_data << completed_ids.size
    end

    series = [
      { name: 'Started that week', data: started_data },
      { name: 'Check-in that week (not started that week)', data: check_in_data },
      { name: 'Ongoing, no check-in that week', data: ongoing_no_check_in_data },
      { name: 'Completed that week', data: completed_data }
    ]
    { categories: categories, series: series }
  end

  # For a single owner: counts of active goals with / without a check-in that week (not employee counts).
  def self.owner_check_in_series(chart_range, goals_scope)
    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }

    no_check_in_data = []
    with_check_in_data = []

    week_dates.each do |w|
      week_end_d = w + 6.days
      week_end_time = week_end_d.to_time.end_of_day
      week_start_time = w.to_time.beginning_of_day

      active_goal_ids = goals_scope
        .where.not(started_at: nil)
        .where('started_at <= ?', week_end_time)
        .where('completed_at IS NULL OR completed_at >= ?', week_start_time)
        .pluck(:id)

      goal_ids_checked_in_this_week = GoalCheckIn.where(check_in_week_start: w, goal_id: active_goal_ids).pluck(:goal_id).uniq
      with_check_in = goal_ids_checked_in_this_week.size
      no_check_in = (active_goal_ids - goal_ids_checked_in_this_week).size

      no_check_in_data << no_check_in
      with_check_in_data << with_check_in
    end

    series = [
      { name: 'Goals with no check-in that week', data: no_check_in_data },
      { name: 'Goals with at least one check-in that week', data: with_check_in_data }
    ]
    { categories: categories, series: series }
  end

  # Insights: employees with goals (original semantics).
  def self.employees_with_goals_series(chart_range, goals_scope)
    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }

    no_check_in_data = []
    with_check_in_data = []

    week_dates.each do |w|
      week_end_d = w + 6.days
      week_end_time = week_end_d.to_time.end_of_day
      week_start_time = w.to_time.beginning_of_day

      teammates_with_goals = goals_scope
        .owned_by_teammate
        .where.not(started_at: nil)
        .where('started_at <= ?', week_end_time)
        .where('completed_at IS NULL OR completed_at >= ?', week_start_time)
        .distinct
        .pluck(:owner_id)

      goal_ids_checked_in_this_week = GoalCheckIn.where(check_in_week_start: w).pluck(:goal_id).uniq
      teammate_ids_with_check_in = goals_scope
        .where(id: goal_ids_checked_in_this_week)
        .owned_by_teammate
        .distinct
        .pluck(:owner_id)

      with_check_in = (teammates_with_goals & teammate_ids_with_check_in).size
      no_check_in = (teammates_with_goals - teammate_ids_with_check_in).size

      no_check_in_data << no_check_in
      with_check_in_data << with_check_in
    end

    series = [
      { name: 'Employees with goals, no check-in that week', data: no_check_in_data },
      { name: 'Employees with at least one goal checked in that week', data: with_check_in_data }
    ]
    { categories: categories, series: series }
  end
end
