# Weekly goal chart data for Insights and My Growth (owner-scoped).
class GoalsChartSeries
  def self.goals_base_scope(company)
    Goal.where(company: company).where(deleted_at: nil)
  end

  # Stacked column: started / check-in / ongoing (each split overdue vs on track), completed hit/miss.
  # Overdue matches goals index spotlight: active goal with most_likely_target_date before week end (date).
  def self.stacked_series(chart_range, goals_scope)
    week_dates, categories = week_axis(chart_range)

    started_on_track_data = []
    started_overdue_data = []
    check_in_on_track_data = []
    check_in_overdue_data = []
    ongoing_on_track_data = []
    ongoing_overdue_data = []
    completed_hit_data = []
    completed_miss_data = []

    week_dates.each do |w|
      week_end_d = w + 6.days
      week_end_time = week_end_d.to_time.end_of_day
      week_start_time = w.to_time.beginning_of_day

      completed_ids = goals_scope
        .where(completed_at: week_start_time..week_end_time)
        .pluck(:id)
      outcomes = Goals::CompletionOutcome.for_goal_ids(completed_ids)
      completed_hit_ids = completed_ids.select { |id| outcomes[id] == :hit }
      completed_miss_ids = completed_ids.select { |id| outcomes[id] == :miss }

      started_scope = goals_scope
        .where(started_at: week_start_time..week_end_time)
        .where.not(id: completed_ids)
      started_ids = started_scope.pluck(:id)
      started_overdue_ids = started_scope
        .where.not(most_likely_target_date: nil)
        .where('most_likely_target_date < ?', week_end_d)
        .pluck(:id)
      started_on_track_ids = started_ids - started_overdue_ids

      goal_ids_with_check_in_this_week = GoalCheckIn.where(check_in_week_start: w).pluck(:goal_id).uniq
      check_in_scope = goals_scope
        .where(id: goal_ids_with_check_in_this_week)
        .where.not(id: completed_ids + started_ids)
        .where('started_at < ?', week_start_time)
      check_in_ids = check_in_scope.pluck(:id)
      check_in_overdue_ids = check_in_scope
        .where.not(most_likely_target_date: nil)
        .where('most_likely_target_date < ?', week_end_d)
        .pluck(:id)
      check_in_on_track_ids = check_in_ids - check_in_overdue_ids

      ongoing_scope = goals_scope
        .where.not(started_at: nil)
        .where('started_at < ?', week_start_time)
        .where('completed_at IS NULL OR completed_at > ?', week_end_time)
        .where.not(id: GoalCheckIn.where(check_in_week_start: w).select(:goal_id))
      ongoing_ids = ongoing_scope.pluck(:id)
      ongoing_ids -= completed_ids
      ongoing_ids -= started_ids
      ongoing_ids -= check_in_ids
      overdue_scope = goals_scope.where(id: ongoing_ids)
        .where.not(most_likely_target_date: nil)
        .where('most_likely_target_date < ?', week_end_d)
      ongoing_overdue_ids = overdue_scope.pluck(:id)
      ongoing_on_track_ids = ongoing_ids - ongoing_overdue_ids

      started_on_track_data << started_on_track_ids.size
      started_overdue_data << started_overdue_ids.size
      check_in_on_track_data << check_in_on_track_ids.size
      check_in_overdue_data << check_in_overdue_ids.size
      ongoing_on_track_data << ongoing_on_track_ids.size
      ongoing_overdue_data << ongoing_overdue_ids.size
      completed_hit_data << completed_hit_ids.size
      completed_miss_data << completed_miss_ids.size
    end

    series = [
      { name: 'Started that week (on track)', data: started_on_track_data },
      { name: 'Started that week (overdue)', data: started_overdue_data },
      { name: 'Confidence check that week — on track', data: check_in_on_track_data },
      { name: 'Confidence check that week — overdue', data: check_in_overdue_data },
      { name: 'Ongoing, no confidence check — on track', data: ongoing_on_track_data },
      { name: 'Ongoing, no confidence check — overdue', data: ongoing_overdue_data },
      { name: 'Completed and hit that week', data: completed_hit_data },
      { name: 'Completed and missed that week', data: completed_miss_data }
    ]
    { categories: categories, series: series }
  end

  # Goals carried week to week: created buckets, then stayed, until completed (completed week only).
  def self.lifecycle_series(chart_range, goals_scope)
    week_dates, categories = week_axis(chart_range)
    chart_start = chart_range.begin.beginning_of_day
    chart_end = chart_range.end.end_of_day

    rows = goals_scope
      .where('created_at <= ?', chart_end)
      .where('completed_at IS NULL OR completed_at >= ?', chart_start)
      .pluck(:id, :created_at, :started_at, :completed_at)

    outcomes = Goals::CompletionOutcome.for_goal_ids(rows.map(&:first))

    keys = %i[created_started created_unstarted stayed_started stayed_unstarted completed_hit completed_miss]
    tallies = keys.index_with { Array.new(week_dates.size, 0) }

    week_dates.each_with_index do |w, idx|
      ws = w.to_time.beginning_of_day
      we = (w + 6.days).to_time.end_of_day
      rows.each do |goal_id, created_at, started_at, completed_at|
        bucket = lifecycle_bucket(created_at, started_at, completed_at, ws, we, outcomes[goal_id])
        tallies[bucket][idx] += 1 if bucket
      end
    end

    series = [
      { name: 'Created (started in same week)', data: tallies[:created_started] },
      { name: 'Created (unstarted)', data: tallies[:created_unstarted] },
      { name: 'Stayed started', data: tallies[:stayed_started] },
      { name: 'Stayed unstarted', data: tallies[:stayed_unstarted] },
      { name: 'Completed and hit that week', data: tallies[:completed_hit] },
      { name: 'Completed and missed that week', data: tallies[:completed_miss] }
    ]
    { categories: categories, series: series }
  end

  # One bucket per teammate (priority): completed+hit > completed+miss > active started > all unstarted.
  def self.employees_goal_weekly_status_series(chart_range, goals_scope)
    week_dates, categories = week_axis(chart_range)
    chart_start = chart_range.begin.beginning_of_day
    chart_end = chart_range.end.end_of_day

    scope = goals_scope.owned_by_teammate
      .where('created_at <= ?', chart_end)
      .where('completed_at IS NULL OR completed_at >= ?', chart_start)

    rows = scope.pluck(:id, :owner_id, :created_at, :started_at, :completed_at)
    outcomes = Goals::CompletionOutcome.for_goal_ids(rows.map(&:first))
    by_owner = rows.group_by { |r| r[1] }.transform_values { |rs| rs.map { |r| [r[0], *r.drop(2)] } }

    completed_hit_week_data = []
    completed_miss_week_data = []
    has_started_active_data = []
    all_unstarted_data = []

    week_dates.each do |w|
      ws = w.to_time.beginning_of_day
      we = (w + 6.days).to_time.end_of_day
      hit_ct = 0
      miss_ct = 0
      started_ct = 0
      unstarted_ct = 0

      by_owner.each do |_owner_id, tuples|
        next if tuples.empty?

        any_hit_this_week = false
        any_miss_this_week = false
        any_started_active = false
        any_only_unstarted = false
        visible = false

        tuples.each do |goal_id, created_at, started_at, completed_at|
          next if created_at > we
          next if completed_at && completed_at < ws

          visible = true
          if completed_at && completed_at >= ws && completed_at <= we
            case outcomes[goal_id]
            when :hit then any_hit_this_week = true
            when :miss then any_miss_this_week = true
            end
          end

          still_open_at_week_end = !completed_at || completed_at > we
          next unless still_open_at_week_end

          if started_at && started_at <= we
            any_started_active = true
          else
            any_only_unstarted = true
          end
        end

        next unless visible

        if any_hit_this_week
          hit_ct += 1
        elsif any_miss_this_week
          miss_ct += 1
        elsif any_started_active
          started_ct += 1
        elsif any_only_unstarted
          unstarted_ct += 1
        end
      end

      completed_hit_week_data << hit_ct
      completed_miss_week_data << miss_ct
      has_started_active_data << started_ct
      all_unstarted_data << unstarted_ct
    end

    series = [
      { name: 'Completed and hit a goal this week', data: completed_hit_week_data },
      { name: 'Completed and missed a goal this week', data: completed_miss_week_data },
      { name: 'Has active started goal(s)', data: has_started_active_data },
      { name: 'Has goals, all unstarted', data: all_unstarted_data }
    ]
    { categories: categories, series: series }
  end

  # Weekly counts by structural association (top / top+prompt / has parent) × status for in-flight goals.
  def self.association_structure_series(chart_range, goals_scope)
    week_dates, categories = week_axis(chart_range)
    chart_start = chart_range.begin.beginning_of_day
    chart_end = chart_range.end.end_of_day

    goal_rows = goals_scope
      .where('created_at <= ?', chart_end)
      .where('completed_at IS NULL OR completed_at >= ?', chart_start)
      .pluck(:id, :created_at, :started_at, :completed_at)

    goal_ids = goal_rows.map(&:first)
    if goal_ids.empty?
      empty = association_segment_definitions.map do |d|
        { name: d[:name], data: Array.new(week_dates.size, 0) }
      end
      return { categories: categories, series: empty }
    end

    outcomes = Goals::CompletionOutcome.for_goal_ids(goal_ids)
    parent_ids = GoalLink.where(child_id: goal_ids).distinct.pluck(:child_id).to_set
    prompt_ids = PromptGoal.where(goal_id: goal_ids).distinct.pluck(:goal_id).to_set

    meta = goal_rows.map do |id, created_at, started_at, completed_at|
      struct =
        if parent_ids.include?(id)
          :has_parent
        elsif prompt_ids.include?(id)
          :top_with_prompt
        else
          :top_no_prompt
        end
      [id, struct, created_at, started_at, completed_at]
    end

    defs = association_segment_definitions
    tallies = defs.map { Array.new(week_dates.size, 0) }

    week_dates.each_with_index do |w, idx|
      ws = w.to_time.beginning_of_day
      we = (w + 6.days).to_time.end_of_day
      meta.each do |goal_id, struct, created_at, started_at, completed_at|
        status = association_status(created_at, started_at, completed_at, ws, we, outcomes[goal_id])
        next unless status

        seg_idx = defs.index { |d| d[:struct] == struct && d[:status] == status }
        tallies[seg_idx][idx] += 1 if seg_idx
      end
    end

    series = defs.each_with_index.map do |d, i|
      { name: d[:name], data: tallies[i] }
    end
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
      { name: 'Goals with no confidence check that week', data: no_check_in_data },
      { name: 'Goals with at least one confidence check that week', data: with_check_in_data }
    ]
    { categories: categories, series: series }
  end

  def self.week_axis(chart_range)
    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }
    [week_dates, categories]
  end

  def self.lifecycle_bucket(created_at, started_at, completed_at, week_start_time, week_end_time, outcome = nil)
    return nil if created_at > week_end_time
    return nil if completed_at && completed_at < week_start_time

    if completed_at && completed_at >= week_start_time && completed_at <= week_end_time
      return :completed_hit if outcome == :hit
      return :completed_miss if outcome == :miss

      return nil
    end

    if created_at >= week_start_time && created_at <= week_end_time
      if started_at && started_at <= week_end_time
        :created_started
      else
        :created_unstarted
      end
    elsif started_at && started_at <= week_end_time
      :stayed_started
    else
      :stayed_unstarted
    end
  end

  def self.association_status(created_at, started_at, completed_at, week_start_time, week_end_time, outcome = nil)
    return nil if created_at > week_end_time
    return nil if completed_at && completed_at < week_start_time

    if completed_at && completed_at >= week_start_time && completed_at <= week_end_time
      return :completed_hit if outcome == :hit
      return :completed_miss if outcome == :miss

      return nil
    elsif started_at && started_at <= week_end_time
      :started
    else
      :unstarted
    end
  end

  def self.association_segment_definitions
    [
      { struct: :top_no_prompt, status: :unstarted, name: 'Top-level, no prompt — unstarted' },
      { struct: :top_no_prompt, status: :started, name: 'Top-level, no prompt — started' },
      { struct: :top_no_prompt, status: :completed_hit, name: 'Top-level, no prompt — completed and hit (this week)' },
      { struct: :top_no_prompt, status: :completed_miss, name: 'Top-level, no prompt — completed and missed (this week)' },
      { struct: :top_with_prompt, status: :unstarted, name: 'Top-level, with prompt — unstarted' },
      { struct: :top_with_prompt, status: :started, name: 'Top-level, with prompt — started' },
      { struct: :top_with_prompt, status: :completed_hit, name: 'Top-level, with prompt — completed and hit (this week)' },
      { struct: :top_with_prompt, status: :completed_miss, name: 'Top-level, with prompt — completed and missed (this week)' },
      { struct: :has_parent, status: :unstarted, name: 'Has parent(s) — unstarted' },
      { struct: :has_parent, status: :started, name: 'Has parent(s) — started' },
      { struct: :has_parent, status: :completed_hit, name: 'Has parent(s) — completed and hit (this week)' },
      { struct: :has_parent, status: :completed_miss, name: 'Has parent(s) — completed and missed (this week)' }
    ]
  end
  private_class_method :week_axis, :lifecycle_bucket, :association_status, :association_segment_definitions
end
