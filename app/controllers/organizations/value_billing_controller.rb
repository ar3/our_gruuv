class Organizations::ValueBillingController < Organizations::OrganizationNamespaceBaseController
  include InsightsTimeframeSelection

  WEEKLY_MILESTONE_VALUE = 1.0
  WEEKLY_OBSERVEE_VALUE = 0.5
  WEEKLY_CHECK_IN_VALUE = 0.5
  WEEKLY_GOAL_CHECK_IN_VALUE = 0.25

  def show
    authorize organization, :show?

    @timeframe = parse_timeframe(params[:timeframe])
    range, @insights_custom_from, @insights_custom_to = insights_date_range_and_custom_fields
    chart_range = range || (52.weeks.ago..Time.current)
    @value_billing_period_label = insights_chart_title_period(@timeframe, range, chart_range)

    teammate_ids_scope = CompanyTeammate.for_organization_hierarchy(company).select(:id)
    week_dates = build_week_dates(chart_range)

    milestone_counts = weekly_milestone_counts(teammate_ids_scope, chart_range)
    observee_counts = weekly_observee_counts(chart_range)
    completed_check_in_counts = weekly_completed_check_in_counts(teammate_ids_scope, chart_range)
    goal_check_in_counts = weekly_goal_check_in_counts(chart_range)

    @value_billing_chart_data = build_chart_data(
      week_dates,
      milestone_counts,
      observee_counts,
      completed_check_in_counts,
      goal_check_in_counts
    )

    assign_per_employee_value_metrics
  end

  private

  def build_week_dates(chart_range)
    (chart_range.begin.to_date..chart_range.end.to_date)
      .map(&:beginning_of_week)
      .uniq
      .sort
  end

  def weekly_milestone_counts(teammate_ids_scope, chart_range)
    TeammateMilestone
      .where(teammate_id: teammate_ids_scope)
      .where(attained_at: chart_range.begin.to_date..chart_range.end.to_date)
      .group(Arel.sql("date_trunc('week', teammate_milestones.attained_at)::date"))
      .count
  end

  def weekly_observee_counts(chart_range)
    Observee
      .joins(:observation)
      .where(observations: { company_id: company.id })
      .merge(Observation.not_soft_deleted.published)
      .where(observations: { published_at: chart_range })
      .group(Arel.sql("date_trunc('week', observations.published_at)::date"))
      .count(:id)
  end

  def weekly_completed_check_in_counts(teammate_ids_scope, chart_range)
    assignment_counts = AssignmentCheckIn
      .where(teammate_id: teammate_ids_scope, official_check_in_completed_at: chart_range)
      .group(Arel.sql("date_trunc('week', assignment_check_ins.official_check_in_completed_at)::date"))
      .count

    aspiration_counts = AspirationCheckIn
      .where(teammate_id: teammate_ids_scope, official_check_in_completed_at: chart_range)
      .group(Arel.sql("date_trunc('week', aspiration_check_ins.official_check_in_completed_at)::date"))
      .count

    position_counts = PositionCheckIn
      .where(teammate_id: teammate_ids_scope, official_check_in_completed_at: chart_range)
      .group(Arel.sql("date_trunc('week', position_check_ins.official_check_in_completed_at)::date"))
      .count

    all_weeks = assignment_counts.keys | aspiration_counts.keys | position_counts.keys
    all_weeks.each_with_object({}) do |week, hash|
      hash[week] = assignment_counts[week].to_i + aspiration_counts[week].to_i + position_counts[week].to_i
    end
  end

  def weekly_goal_check_in_counts(chart_range)
    GoalCheckIn
      .joins(:goal)
      .where(goals: { company_id: company.id })
      .where(created_at: chart_range)
      .group(Arel.sql("date_trunc('week', goal_check_ins.created_at)::date"))
      .count
  end

  def build_chart_data(week_dates, milestone_counts, observee_counts, completed_check_in_counts, goal_check_in_counts)
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }
    milestone_data = week_dates.map { |wd| milestone_counts[wd] || 0 }
    observee_data = week_dates.map { |wd| observee_counts[wd] || 0 }
    completed_check_in_data = week_dates.map { |wd| completed_check_in_counts[wd] || 0 }
    goal_check_in_data = week_dates.map { |wd| goal_check_in_counts[wd] || 0 }

    total_value_data = week_dates.each_with_index.map do |_wd, idx|
      (milestone_data[idx] * WEEKLY_MILESTONE_VALUE) +
        (observee_data[idx] * WEEKLY_OBSERVEE_VALUE) +
        (completed_check_in_data[idx] * WEEKLY_CHECK_IN_VALUE) +
        (goal_check_in_data[idx] * WEEKLY_GOAL_CHECK_IN_VALUE)
    end

    {
      categories: categories,
      total_value: total_value_data,
      milestones: milestone_data,
      observees: observee_data,
      completed_check_ins: completed_check_in_data,
      goal_check_ins: goal_check_in_data
    }
  end

  def assign_per_employee_value_metrics
    totals = @value_billing_chart_data[:total_value]
    @value_billing_total_value_sum = totals.sum
    @value_billing_week_count = totals.size
    @value_billing_active_teammate_count =
      CompanyTeammate.for_organization_hierarchy(company).employed.count

    if @value_billing_week_count.positive? && @value_billing_active_teammate_count.positive?
      avg_weekly = @value_billing_total_value_sum / @value_billing_week_count
      @value_billing_per_employee_week = avg_weekly / @value_billing_active_teammate_count
      @value_billing_per_employee_year = @value_billing_per_employee_week * 52
    else
      @value_billing_per_employee_week = nil
      @value_billing_per_employee_year = nil
    end
  end
end
