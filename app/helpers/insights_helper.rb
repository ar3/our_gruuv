module InsightsHelper
  # Seats by state chart data
  def seats_by_state_chart_data
    state_colors = {
      'draft' => '#6c757d',
      'open' => '#ffc107',
      'filled' => '#28a745',
      'archived' => '#dc3545'
    }
    
    @seats_by_state.map do |state, count|
      {
        name: state.titleize,
        y: count,
        color: state_colors[state] || '#007bff'
      }
    end
  end
  
  # Department categories for stacked bar chart
  def department_categories
    all_depts = (@open_seats_by_department.keys + @filled_seats_by_department.keys).uniq.sort
    all_depts.empty? ? ['No Data'] : all_depts
  end
  
  # Open seats data array
  def open_seats_data
    categories = department_categories
    categories.map { |dept| @open_seats_by_department[dept] || 0 }
  end
  
  # Filled seats data array
  def filled_seats_data
    categories = department_categories
    categories.map { |dept| @filled_seats_by_department[dept] || 0 }
  end
  
  # Titles by department chart data
  def titles_by_department_chart_data
    data = @titles_by_department.map do |dept_name, count|
      { name: dept_name, y: count }
    end
    
    if @titles_no_department > 0
      data << { name: 'No Department', y: @titles_no_department }
    end
    
    data.empty? ? [{ name: 'No Data', y: 0 }] : data
  end
  
  # Titles by position count categories
  def titles_by_position_count_categories
    return ['0 positions'] if @titles_by_position_count.empty?
    
    @titles_by_position_count.keys.map do |count|
      count == 1 ? '1 position' : "#{count} positions"
    end
  end
  
  # Titles by position count data
  def titles_by_position_count_data
    return [0] if @titles_by_position_count.empty?
    @titles_by_position_count.values
  end
  
  # Positions by assignment count categories
  def positions_by_assignment_count_categories
    return ['0 assignments'] if @positions_by_required_assignment_count.empty?
    
    @positions_by_required_assignment_count.keys.map do |count|
      count == 1 ? '1 assignment' : "#{count} assignments"
    end
  end
  
  # Positions by assignment count data
  def positions_by_assignment_count_data
    return [0] if @positions_by_required_assignment_count.empty?
    @positions_by_required_assignment_count.values
  end

  # Who is doing what: pie chart (teammates with vs without page visit)
  def who_is_doing_what_pie_chart_data
    with_visit = @active_teammates_with_visit.to_i
    without_visit = @active_teammates_without_visit.to_i
    total = with_visit + without_visit
    if total.zero?
      return [{ name: 'No data', y: 0, color: '#6c757d' }]
    end
    [
      { name: 'Has page visit', y: with_visit, color: '#28a745' },
      { name: 'No page visit', y: without_visit, color: '#6c757d' }
    ].reject { |d| d[:y].zero? }
  end

  # Who is doing what: histogram categories (department #id labels)
  def who_is_doing_what_histogram_categories
    return [] unless @teammate_visit_counts.is_a?(Array)
    @teammate_visit_counts.map { |h| h[:label] }
  end

  # Who is doing what: histogram data (visit counts)
  def who_is_doing_what_histogram_data
    return [] unless @teammate_visit_counts.is_a?(Array)
    @teammate_visit_counts.map { |h| h[:count] }
  end

  WHO_IS_DOING_WHAT_DIGEST_INACTIVE_STACK_COLOR = '#6c757d'.freeze

  def who_is_doing_what_gsd_medium_series
    return [] if @gsd_digest_medium_combinations.values.sum.to_i.zero?

    @gsd_digest_medium_combinations
      .sort_by { |label, _count| label == 'off' ? 1 : 0 }
      .map do |label, count|
        who_is_doing_what_digest_stacked_series_entry(label, count, inactive: label == 'off')
      end
  end

  def who_is_doing_what_about_me_day_series
    return [] if @about_me_digest_day_distribution.values.sum.to_i.zero?

    day_labels = { '0' => 'Sunday', '1' => 'Monday', '2' => 'Tuesday', '3' => 'Wednesday', '4' => 'Thursday', '5' => 'Friday', '6' => 'Saturday', 'off' => 'No 1:1s' }
    @about_me_digest_day_distribution
      .sort_by { |day, _count| day.to_s == 'off' ? [1, 0] : [0, day.to_i] }
      .map do |day, count|
        name = day_labels[day.to_s] || day.to_s
        who_is_doing_what_digest_stacked_series_entry(name, count, inactive: day.to_s == 'off')
      end
  end

  WHO_IS_DOING_WHAT_WEEKLY_DIGEST_TYPE_ORDER = %w[one_on_one_only about_me_only both none].freeze
  WHO_IS_DOING_WHAT_WEEKLY_DIGEST_TYPE_LABELS = {
    'one_on_one_only' => '1:1 guide only',
    'about_me_only' => 'About Me reminder only',
    'both' => 'Both digests',
    'none' => 'No weekly digests'
  }.freeze

  def who_is_doing_what_weekly_digest_type_series
    return [] unless @weekly_digest_type_distribution.is_a?(Hash)

    total = WHO_IS_DOING_WHAT_WEEKLY_DIGEST_TYPE_ORDER.sum { |key| @weekly_digest_type_distribution[key].to_i }
    return [] if total.zero?

    WHO_IS_DOING_WHAT_WEEKLY_DIGEST_TYPE_ORDER.map do |key|
      who_is_doing_what_digest_stacked_series_entry(
        WHO_IS_DOING_WHAT_WEEKLY_DIGEST_TYPE_LABELS[key],
        @weekly_digest_type_distribution.fetch(key, 0),
        inactive: key == 'none'
      )
    end
  end

  def who_is_doing_what_digest_stacked_series_entry(name, count, inactive: false)
    entry = { name: name, data: [count.to_i] }
    entry[:color] = WHO_IS_DOING_WHAT_DIGEST_INACTIVE_STACK_COLOR if inactive
    entry
  end

  def og_scorecard_weekly_cell_class(status)
    case status.to_sym
    when :success then 'table-success'
    when :warning then 'table-warning'
    when :danger then 'table-danger'
    else 'og-scorecard-cell-neutral'
    end
  end

  def og_scorecard_direction_label(direction)
    case direction.to_sym
    when :more then 'More is better'
    when :less then 'Less is better'
    else '—'
    end
  end
end
