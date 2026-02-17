class Organizations::InsightsController < Organizations::OrganizationNamespaceBaseController
  def seats_titles_positions
    authorize company, :view_seats?
    
    # Seat statistics
    seats = Seat.for_organization(company)
    @total_seats = seats.count
    @seats_by_state = seats.group(:state).count
    
    # Seats by department (for pie chart)
    @seats_by_department = seats
      .joins(title: :department)
      .where.not(titles: { department_id: nil })
      .group('departments.name')
      .count
    @seats_no_department = seats.joins(:title).where(titles: { department_id: nil }).count
    
    # Open vs filled seats by department
    open_and_filled_seats = seats.where(state: [:open, :filled])
    @open_seats_by_department = build_department_breakdown(open_and_filled_seats.where(state: :open))
    @filled_seats_by_department = build_department_breakdown(open_and_filled_seats.where(state: :filled))
    
    # Title statistics
    titles = Title.where(company: company)
    @total_titles = titles.count
    @titles_by_department = titles
      .joins(:department)
      .where.not(department_id: nil)
      .group('departments.name')
      .count
    @titles_no_department = titles.where(department_id: nil).count
    
    # Position statistics
    positions = Position.joins(:title).where(titles: { company_id: company.id })
    @total_positions = positions.count
    
    # Titles by position count
    @titles_by_position_count = titles
      .left_joins(:positions)
      .group('titles.id')
      .count('positions.id')
      .values
      .tally
      .sort_by { |k, _v| k }
      .to_h
    
    # Positions by required assignment count
    @positions_by_required_assignment_count = positions
      .left_joins(:position_assignments)
      .where(position_assignments: { assignment_type: 'required' })
      .or(positions.left_joins(:position_assignments).where(position_assignments: { id: nil }))
      .group('positions.id')
      .count('position_assignments.id')
      .values
      .tally
      .sort_by { |k, _v| k }
      .to_h
  end
  
  def assignments
    authorize company, :view_assignments?

    @organization = company
    @total_assignments = Assignment.where(company: company).count
    assignments_scope = Assignment.for_company(company)
    @outcomes_distribution_chart_data = assignments_outcomes_distribution_chart_data(assignments_scope)
    @positions_distribution_chart_data = assignments_positions_distribution_chart_data(assignments_scope)

    @timeframe = parse_timeframe(params[:timeframe])
    range = date_range_for(@timeframe)
    chart_range = range || (52.weeks.ago..Time.current)
    @chart_title_period = case @timeframe
      when :'90_days' then 'Last 90 Days'
      when :year then 'Last Year'
      when :all_time then 'Last 52 Weeks'
      else 'Last 90 Days'
    end
    @assignments_updated_chart_data = assignments_updated_chart_data(company, chart_range)
    @finalized_check_ins_chart_data = assignments_finalized_check_ins_chart_data(company, chart_range)
    @observation_ratings_chart_data = assignments_observation_ratings_chart_data(company, chart_range)
  end
  
  def abilities
    authorize company, :view_abilities?

    @organization = company
    @total_abilities = Ability.where(company: company).count
    abilities_scope = Ability.for_company(company)
    @milestones_distribution_chart_data = abilities_milestones_distribution_chart_data(abilities_scope)
    @assignments_per_ability_chart_data = abilities_assignments_per_milestone_chart_data(abilities_scope)

    @timeframe = parse_timeframe(params[:timeframe])
    range = date_range_for(@timeframe)
    chart_range = range || (52.weeks.ago..Time.current)
    @chart_title_period = case @timeframe
      when :'90_days' then 'Last 90 Days'
      when :year then 'Last Year'
      when :all_time then 'Last 52 Weeks'
      else 'Last 90 Days'
    end
    @abilities_updated_chart_data = abilities_updated_chart_data(company, chart_range)
    @milestones_earned_chart_data = abilities_milestones_earned_chart_data(company, chart_range)
    @observation_ratings_chart_data = abilities_observation_ratings_chart_data(company, chart_range)
  end
  
  def goals
    authorize company, :view_goals?

    @organization = company
    @timeframe = parse_timeframe(params[:timeframe])
    range = date_range_for(@timeframe)
    chart_range = range || (52.weeks.ago..Time.current)
    @goals_chart_data = goals_stacked_chart_series(chart_range)
    @goals_employees_chart_data = goals_employees_chart_series(chart_range)
  end

  def prompts
    authorize company, :view_prompts?

    @organization = company
    @timeframe = parse_timeframe(params[:timeframe])
    range = date_range_for(@timeframe)
    chart_range = range || (52.weeks.ago..Time.current)
    @prompts_answers_chart_data = prompts_answers_chart_series(chart_range)
    @prompts_teammates_chart_data = prompts_teammates_chart_series(chart_range)
    @prompts_download_teammate_count = prompts_download_teammate_scope.count
  end

  def prompts_download
    authorize company, :view_prompts?

    teammate_ids = prompts_download_teammate_scope.pluck(:id)
    csv_content = PromptsInsightsCsvBuilder.new(company, teammate_ids: teammate_ids).call
    filename = "active_prompts_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    send_data csv_content,
              filename: filename,
              type: 'text/csv',
              disposition: 'attachment'
  end

  def feedback_requests
    authorize company, :view_feedback_requests?

    @organization = company
    @timeframe = parse_timeframe(params[:timeframe])
    range = date_range_for(@timeframe)
    chart_range = range || (52.weeks.ago..Time.current)
    @feedback_requests_created_chart_data = feedback_requests_created_chart_series(chart_range)
    @feedback_observations_published_chart_data = feedback_observations_published_chart_series(chart_range)
    @top_feedback_givers = top_feedback_givers_for_insights(range)
    @top_assignments_feedback_requested = top_assignments_feedback_requested_for_insights(range)
    @top_abilities_feedback_requested = top_abilities_feedback_requested_for_insights(range)
  end

  def observations
    authorize company, :view_observations?

    @organization = company
    @timeframe = parse_timeframe(params[:timeframe])
    range = date_range_for(@timeframe)

    base_scope = Observation.for_company(company).not_soft_deleted.published
    base_scope = base_scope.where(observed_at: range) if range

    chart_range = range || (52.weeks.ago..Time.current)
    @observations_chart_data = observations_chart_series_by_privacy(base_scope, chart_range)

    # Observers (person_ids) who have given at least one observation
    observer_ids = base_scope.distinct.pluck(:observer_id).compact
    @observer_teammates = CompanyTeammate
      .where(organization: company)
      .where(person_id: observer_ids)
      .includes(employment_tenures: { position: { title: :department } })

    # Aggregate kudos / feedback / mixed per observer (load observations with ratings)
    observations_with_bucket = base_scope.includes(:observation_ratings).to_a
    @kudos_feedback_mixed_by_observer = Hash.new { |h, k| h[k] = { kudos: 0, feedback: 0, mixed: 0 } }
    observations_with_bucket.each do |obs|
      bucket = obs.kudos_or_feedback_bucket
      @kudos_feedback_mixed_by_observer[obs.observer_id][bucket] += 1
    end

    # Aggregate count by privacy_level per observer
    @privacy_counts_by_observer = Hash.new { |h, k| h[k] = Hash.new(0) }
    base_scope.pluck(:observer_id, :privacy_level).each do |observer_id, privacy_level|
      @privacy_counts_by_observer[observer_id][privacy_level] += 1
    end

    # Total published unarchived observations per observer (for column and sorting)
    @total_published_unarchived_by_observer = base_scope.group(:observer_id).count

    # All privacy levels for table columns (use enum order)
    @privacy_levels = Observation.privacy_levels.keys
  end

  def who_is_doing_what
    authorize company, :view_observations?

    @organization = company
    active_teammates = CompanyTeammate.where(organization: company).employed
    teammate_person_ids = active_teammates.pluck(:person_id).uniq

    # Pie: active teammates with ≥1 page visit vs without
    person_ids_with_visit = PageVisit.where(person_id: teammate_person_ids).distinct.pluck(:person_id)
    with_visit_count = person_ids_with_visit.size
    without_visit_count = [0, teammate_person_ids.size - with_visit_count].max
    @active_teammates_with_visit = with_visit_count
    @active_teammates_without_visit = without_visit_count

    # Top 10 pages (by total visit_count) in this org
    top_by_url = PageVisit
      .where(person_id: teammate_person_ids)
      .group(:url)
      .sum(:visit_count)
      .sort_by { |_url, count| -count }
      .first(10)
    # Get one page_title per url for display
    urls = top_by_url.map(&:first)
    titles_by_url = PageVisit
      .where(person_id: teammate_person_ids, url: urls)
      .order(visited_at: :desc)
      .pluck(:url, :page_title)
      .each_with_object({}) { |(url, title), h| h[url] = title.presence || url unless h.key?(url) }
    @top_pages = top_by_url.map do |url, count|
      { url: url, visit_count: count, page_title: titles_by_url[url] || url }
    end

    # Histogram: each active teammate labeled by department + id, value = total page visits (top 30)
    active_teammates_with_dept = active_teammates
      .includes(:person, employment_tenures: { position: { title: :department } })
    visit_totals_by_person = PageVisit.where(person_id: teammate_person_ids).group(:person_id).sum(:visit_count)
    @teammate_visit_counts = active_teammates_with_dept.map do |tm|
      dept_name = tm.active_employment_tenure&.position&.title&.department&.name.presence || 'No Department'
      label = "#{dept_name} ##{tm.id}"
      count = visit_totals_by_person[tm.person_id].to_i
      { label: label, count: count }
    end.sort_by { |h| -h[:count] }.first(30)

    # Period stats: unique page visits (records with visited_at in range) and unique users
    @period_stats = {}
    [
      [7.days.ago..Time.current, :week],
      [30.days.ago..Time.current, :month],
      [90.days.ago..Time.current, :'90_days']
    ].each do |range, key|
      scope = PageVisit.where(person_id: teammate_person_ids).where(visited_at: range)
      @period_stats[key] = {
        unique_page_visits: scope.count,
        unique_users: scope.distinct.count(:person_id)
      }
    end
  end

  private
  
  def build_department_breakdown(seats_scope)
    result = seats_scope
      .joins(title: :department)
      .where.not(titles: { department_id: nil })
      .group('departments.name')
      .count
    
    no_dept_count = seats_scope.joins(:title).where(titles: { department_id: nil }).count
    result['No Department'] = no_dept_count if no_dept_count > 0
    
    result
  end

  def parse_timeframe(param)
    case param.to_s
    when 'year' then :year
    when 'all_time' then :all_time
    else :'90_days'
    end
  end

  def date_range_for(timeframe)
    case timeframe
    when :'90_days'
      90.days.ago..Time.current
    when :year
      1.year.ago..Time.current
    when :all_time
      nil
    else
      90.days.ago..Time.current
    end
  end

  def prompts_download_teammate_scope
    base = CompanyTeammate.for_organization_hierarchy(company)
      .where.not(first_employed_at: nil)
      .where(last_terminated_at: nil)

    if policy(company).manage_employment? || current_company_teammate&.can_manage_prompts?
      base
    else
      return base.none unless current_company_teammate
      hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, company).pluck(:id)
      base.where(id: hierarchy_ids)
    end
  end

  def prompts_answers_chart_series(chart_range)
    # Query from Prompt so joins to company_teammates and prompt_templates are correct
    base_scope = PromptAnswer
      .joins(:prompt)
      .joins('INNER JOIN teammates ON teammates.id = prompts.company_teammate_id')
      .joins('INNER JOIN prompt_templates ON prompt_templates.id = prompts.prompt_template_id')
      .where(prompts: { closed_at: nil })
      .where(teammates: { organization_id: company.id })
      .where(prompt_templates: { company_id: company.id })
      .where("LENGTH(TRIM(COALESCE(prompt_answers.text, ''))) > 10")

    rows = base_scope.pluck('prompt_templates.id', 'prompt_templates.title', 'prompt_answers.created_at')

    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }

    all_templates = PromptTemplate.where(company_id: company.id).ordered
    series = all_templates.map do |template|
      {
        name: template.title,
        data: week_dates.map do |wd|
          week_end = wd.to_time.end_of_week.end_of_day
          rows.count { |id, _title, created_at| id == template.id && created_at && created_at <= week_end }
        end
      }
    end
    { categories: categories, series: series }
  end

  def prompts_teammates_chart_series(chart_range)
    # Prompts (open) that have at least one answer with content, scoped to company
    prompts_with_content = Prompt
      .open
      .joins('INNER JOIN teammates ON teammates.id = prompts.company_teammate_id')
      .joins('INNER JOIN prompt_templates ON prompt_templates.id = prompts.prompt_template_id')
      .where(teammates: { organization_id: company.id })
      .where(prompt_templates: { company_id: company.id })
      .where(id: PromptAnswer.where("LENGTH(TRIM(COALESCE(prompt_answers.text, ''))) > 10").select(:prompt_id))

    rows = prompts_with_content.distinct.pluck('prompt_templates.id', 'prompt_templates.title', 'teammates.id', 'prompts.created_at')

    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }

    all_templates = PromptTemplate.where(company_id: company.id).ordered
    series = all_templates.map do |template|
      {
        name: template.title,
        data: week_dates.map do |wd|
          week_end = wd.to_time.end_of_week.end_of_day
          teammate_ids = rows.select { |tid, _title, teammate_id, created_at| tid == template.id && created_at && created_at <= week_end }.map { |_t, _title, tid, _ca| tid }.uniq
          teammate_ids.size
        end
      }
    end
    { categories: categories, series: series }
  end

  def observations_chart_series_by_privacy(base_scope, chart_range)
    scope = base_scope.where(observed_at: chart_range)
    raw = scope.group(Arel.sql("date_trunc('week', observed_at)::date"), :privacy_level).count
    raw_normalized = raw.each_with_object(Hash.new(0)) { |((w, p), c), h| h[[w.to_s, p]] = c }

    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map { |d| d.beginning_of_week }.uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }
    series = Observation.privacy_levels.keys.map do |privacy|
      {
        name: privacy.to_s.humanize.titleize,
        data: week_dates.map { |wd| raw_normalized[[wd.to_s, privacy]] || 0 }
      }
    end
    { categories: categories, series: series }
  end

  def feedback_requests_created_chart_series(chart_range)
    scope = FeedbackRequest.where(company: company).where(created_at: chart_range)
    raw = scope.group(Arel.sql("date_trunc('week', created_at)::date")).count
    raw_normalized = raw.transform_keys { |k| k.to_s }

    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map { |d| d.beginning_of_week }.uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }
    data = week_dates.map { |wd| raw_normalized[wd.to_s] || 0 }
    series = [{ name: 'Feedback requests created', data: data }]
    { categories: categories, series: series }
  end

  def feedback_observations_published_chart_series(chart_range)
    scope = Observation
      .for_company(company)
      .not_soft_deleted
      .published
      .where.not(feedback_request_question_id: nil)
      .where(published_at: chart_range)
    raw = scope.group(Arel.sql("date_trunc('week', published_at)::date")).count
    raw_normalized = raw.transform_keys { |k| k.to_s }

    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map { |d| d.beginning_of_week }.uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }
    data = week_dates.map { |wd| raw_normalized[wd.to_s] || 0 }
    series = [{ name: 'Feedback-related observations published', data: data }]
    { categories: categories, series: series }
  end

  def top_feedback_givers_for_insights(range)
    scope = Observation
      .for_company(company)
      .not_soft_deleted
      .published
      .where.not(feedback_request_question_id: nil)
    scope = scope.where(published_at: range) if range
    counts = scope.group(:observer_id).count
    top_10 = counts.sort_by { |_, c| -c }.first(10)
    return [] if top_10.blank?

    persons_by_id = Person.where(id: top_10.map(&:first)).index_by(&:id)
    teammate_by_person_id = CompanyTeammate
      .where(organization: company, person_id: top_10.map(&:first))
      .index_by(&:person_id)
    top_10.filter_map do |observer_id, count|
      person = persons_by_id[observer_id]
      next unless person

      { person: person, company_teammate: teammate_by_person_id[observer_id], count: count }
    end
  end

  def top_assignments_feedback_requested_for_insights(range)
    scope = FeedbackRequestQuestion
      .joins(:feedback_request)
      .where(feedback_requests: { company_id: company.id }, rateable_type: 'Assignment')
      .where.not(rateable_id: nil)
    scope = scope.where(feedback_requests: { created_at: range }) if range
    counts = scope.group(:rateable_id).count
    top_10 = counts.sort_by { |_, c| -c }.first(10)
    return [] if top_10.blank?

    assignments_by_id = Assignment.where(id: top_10.map(&:first)).index_by(&:id)
    top_10.map { |rateable_id, count| { assignment: assignments_by_id[rateable_id], count: count } }.select { |h| h[:assignment].present? }
  end

  def top_abilities_feedback_requested_for_insights(range)
    scope = FeedbackRequestQuestion
      .joins(:feedback_request)
      .where(feedback_requests: { company_id: company.id }, rateable_type: 'Ability')
      .where.not(rateable_id: nil)
    scope = scope.where(feedback_requests: { created_at: range }) if range
    counts = scope.group(:rateable_id).count
    top_10 = counts.sort_by { |_, c| -c }.first(10)
    return [] if top_10.blank?

    abilities_by_id = Ability.where(id: top_10.map(&:first)).index_by(&:id)
    top_10.map { |rateable_id, count| { ability: abilities_by_id[rateable_id], count: count } }.select { |h| h[:ability].present? }
  end

  def goals_base_scope
    Goal.where(company: company).where(deleted_at: nil)
  end

  def goals_stacked_chart_series(chart_range)
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

      completed_ids = goals_base_scope
        .where(completed_at: week_start_time..week_end_time)
        .pluck(:id)

      started_ids = goals_base_scope
        .where(started_at: week_start_time..week_end_time)
        .where.not(id: completed_ids)
        .pluck(:id)

      goal_ids_with_check_in_this_week = GoalCheckIn.where(check_in_week_start: w).pluck(:goal_id).uniq
      check_in_ids = goals_base_scope
        .where(id: goal_ids_with_check_in_this_week)
        .where.not(id: completed_ids + started_ids)
        .where('started_at < ?', week_start_time)
        .pluck(:id)

      ongoing_ids = goals_base_scope
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

  def goals_employees_chart_series(chart_range)
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

      teammates_with_goals = goals_base_scope
        .owned_by_teammate
        .where.not(started_at: nil)
        .where('started_at <= ?', week_end_time)
        .where('completed_at IS NULL OR completed_at >= ?', week_start_time)
        .distinct
        .pluck(:owner_id)

      goal_ids_checked_in_this_week = GoalCheckIn.where(check_in_week_start: w).pluck(:goal_id).uniq
      teammate_ids_with_check_in = goals_base_scope
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

  # --- Assignments insights chart data ---

  def assignments_outcomes_distribution_chart_data(assignments_scope)
    counts = assignments_scope.left_joins(:assignment_outcomes).group(:id).count('assignment_outcomes.id')
    histogram = counts.values.tally.sort_by { |k, _| k }.to_h
    max_n = histogram.keys.max || 0
    categories = (0..max_n).to_a.map(&:to_s)
    data = categories.map { |n| histogram[n.to_i] || 0 }
    { categories: categories, series: [{ name: 'Assignments', data: data }] }
  end

  def assignments_positions_distribution_chart_data(assignments_scope)
    required = assignments_scope.joins(:position_assignments).where(position_assignments: { assignment_type: 'required' }).group(:id).count
    suggested = assignments_scope.joins(:position_assignments).where(position_assignments: { assignment_type: 'suggested' }).group(:id).count
    required_hist = required.values.tally
    suggested_hist = suggested.values.tally
    max_n = (required_hist.keys + suggested_hist.keys).max || 0
    categories = (0..max_n).to_a.map(&:to_s)
    required_data = categories.map { |n| required_hist[n.to_i] || 0 }
    suggested_data = categories.map { |n| suggested_hist[n.to_i] || 0 }
    {
      categories: categories,
      series: [
        { name: 'Requirement', data: required_data },
        { name: 'Suggested', data: suggested_data }
      ]
    }
  end

  def assignments_updated_chart_data(company, chart_range)
    return { categories: [], series: [] } if chart_range.nil?
    assignment_ids = Assignment.for_company(company).pluck(:id)
    return { categories: [], series: [] } if assignment_ids.empty?
    scope = PaperTrail::Version.where(item_type: 'Assignment', item_id: assignment_ids, event: 'update').where(created_at: chart_range)
    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }
    data = week_dates.map do |wd|
      week_start = wd.to_time
      week_end = wd.to_time.end_of_week.end_of_day
      scope.where(created_at: week_start..week_end).distinct.count(:item_id)
    end
    series = [{ name: 'Assignments updated', data: data }]
    { categories: categories, series: series }
  end

  def assignments_finalized_check_ins_chart_data(company, chart_range)
    return { categories: [], series: [] } if chart_range.nil?
    base = AssignmentCheckIn.joins(:assignment).where(assignments: { company_id: company.id }).closed.where(official_check_in_completed_at: chart_range)
    raw = base.group(Arel.sql("date_trunc('week', official_check_in_completed_at)::date"), :official_rating).count
    raw_normalized = raw.each_with_object(Hash.new(0)) { |((w, r), c), h| h[[w.to_s, r]] = c }
    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }
    rating_order = %w[working_to_meet meeting exceeding]
    series = rating_order.map do |rating|
      {
        name: rating.humanize.titleize,
        data: week_dates.map { |wd| raw_normalized[[wd.to_s, rating]] || 0 }
      }
    end
    { categories: categories, series: series }
  end

  def assignments_observation_ratings_chart_data(company, chart_range)
    return { categories: [], series: [] } if chart_range.nil?
    base = ObservationRating
      .joins(:observation)
      .where(rateable_type: 'Assignment')
      .where(observations: { company_id: company.id })
      .merge(Observation.not_soft_deleted.published)
      .where(observations: { published_at: chart_range })
    raw = base.group(Arel.sql("date_trunc('week', observations.published_at)::date"), :rating).count
    raw_normalized = raw.each_with_object(Hash.new(0)) { |((w, r), c), h| h[[w.to_s, r]] = c }
    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }
    rating_labels = {
      'strongly_agree' => 'Exceptional',
      'agree' => 'Solid',
      'disagree' => 'Misaligned',
      'strongly_disagree' => 'Concerning'
    }
    rating_order = %w[strongly_agree agree disagree strongly_disagree]
    series = rating_order.map do |rating|
      {
        name: rating_labels[rating] || rating.humanize,
        data: week_dates.map { |wd| raw_normalized[[wd.to_s, rating]] || 0 }
      }
    end
    { categories: categories, series: series }
  end

  # --- Abilities insights chart data ---

  def abilities_milestones_distribution_chart_data(abilities_scope)
    rows = abilities_scope.pluck(:milestone_1_description, :milestone_2_description, :milestone_3_description, :milestone_4_description, :milestone_5_description)
    counts = rows.map { |row| row.count { |x| x.present? } }
    histogram = counts.tally
    max_n = histogram.keys.max || 0
    categories = (0..max_n).to_a.map(&:to_s)
    data = categories.map { |n| histogram[n.to_i] || 0 }
    { categories: categories, series: [{ name: 'Abilities', data: data }] }
  end

  def abilities_assignments_per_milestone_chart_data(abilities_scope)
    ability_ids = abilities_scope.pluck(:id)
    return { categories: ['0'], series: (1..5).map { |ml| { name: "Milestone #{ml}", data: [0] } } } if ability_ids.empty?

    aa_counts = AssignmentAbility.where(ability_id: ability_ids).group(:ability_id, :milestone_level).count
    max_n = 0
    (1..5).each do |ml|
      ability_ids.each do |aid|
        c = aa_counts[[aid, ml]] || 0
        max_n = c if c > max_n
      end
    end
    categories = (0..max_n).to_a.map(&:to_s)
    series = (1..5).map do |ml|
      hist = ability_ids.each_with_object(Hash.new(0)) { |aid, h| h[aa_counts[[aid, ml]] || 0] += 1 }
      { name: "Milestone #{ml}", data: categories.map { |k| hist[k.to_i] || 0 } }
    end
    { categories: categories, series: series }
  end

  def abilities_updated_chart_data(company, chart_range)
    return { categories: [], series: [] } if chart_range.nil?
    ability_ids = Ability.for_company(company).pluck(:id)
    return { categories: [], series: [] } if ability_ids.empty?
    scope = PaperTrail::Version.where(item_type: 'Ability', item_id: ability_ids, event: 'update').where(created_at: chart_range)
    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }
    data = week_dates.map do |wd|
      week_start = wd.to_time
      week_end = wd.to_time.end_of_week.end_of_day
      scope.where(created_at: week_start..week_end).distinct.count(:item_id)
    end
    series = [{ name: 'Abilities updated', data: data }]
    { categories: categories, series: series }
  end

  def abilities_milestones_earned_chart_data(company, chart_range)
    return { categories: [], series: [] } if chart_range.nil?
    date_range = chart_range.begin.to_date..chart_range.end.to_date
    base = TeammateMilestone
      .joins(:ability)
      .where(abilities: { company_id: company.id })
      .where(attained_at: date_range)
    raw = base.group(Arel.sql("date_trunc('week', teammate_milestones.attained_at)::date"), :milestone_level).count
    raw_normalized = raw.each_with_object(Hash.new(0)) { |((w, ml), c), h| h[[w.to_s, ml]] = c }
    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }
    series = (1..5).map do |ml|
      {
        name: "Milestone #{ml}",
        data: week_dates.map { |wd| raw_normalized[[wd.to_s, ml]] || 0 }
      }
    end
    { categories: categories, series: series }
  end

  def abilities_observation_ratings_chart_data(company, chart_range)
    return { categories: [], series: [] } if chart_range.nil?
    base = ObservationRating
      .joins(:observation)
      .where(rateable_type: 'Ability')
      .where(observations: { company_id: company.id })
      .merge(Observation.not_soft_deleted.published)
      .where(observations: { published_at: chart_range })
    raw = base.group(Arel.sql("date_trunc('week', observations.published_at)::date"), :rating).count
    raw_normalized = raw.each_with_object(Hash.new(0)) { |((w, r), c), h| h[[w.to_s, r]] = c }
    end_date = chart_range.end.to_date
    start_date = chart_range.begin.to_date
    week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
    categories = week_dates.map { |w| w.strftime('%b %d, %Y') }
    rating_labels = {
      'strongly_agree' => 'Exceptional',
      'agree' => 'Solid',
      'disagree' => 'Misaligned',
      'strongly_disagree' => 'Concerning'
    }
    rating_order = %w[strongly_agree agree disagree strongly_disagree]
    series = rating_order.map do |rating|
      {
        name: rating_labels[rating] || rating.humanize,
        data: week_dates.map { |wd| raw_normalized[[wd.to_s, rating]] || 0 }
      }
    end
    { categories: categories, series: series }
  end
end
