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
    
    @total_assignments = Assignment.where(company: company).count
  end
  
  def abilities
    authorize company, :view_abilities?
    
    @total_abilities = Ability.where(company: company).count
  end
  
  def goals
    authorize company, :view_goals?
    
    @total_goals = Goal.where(company: company).count
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
end
