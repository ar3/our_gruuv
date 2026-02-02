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
end
