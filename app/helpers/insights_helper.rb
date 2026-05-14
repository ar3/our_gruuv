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

  def who_is_doing_what_gsd_medium_series
    return [] if @gsd_digest_medium_combinations.values.sum.to_i.zero?

    @gsd_digest_medium_combinations.map do |label, count|
      { name: label, data: [count.to_i] }
    end
  end

  def who_is_doing_what_about_me_day_series
    return [] if @about_me_digest_day_distribution.values.sum.to_i.zero?

    day_labels = { '0' => 'Sunday', '1' => 'Monday', '2' => 'Tuesday', '3' => 'Wednesday', '4' => 'Thursday', '5' => 'Friday', '6' => 'Saturday', 'off' => 'No 1:1s' }
    @about_me_digest_day_distribution.map do |day, count|
      { name: day_labels[day.to_s] || day.to_s, data: [count.to_i] }
    end
  end

  # OG Scorecard: inner HTML for threshold popover (shown when threshold columns are hidden).
  def og_scorecard_threshold_popover_inner_html(row)
    y_txt = row[:yellow].nil? ? '—' : og_scorecard_format_threshold(row[:yellow])
    g_txt = row[:green].nil? ? '—' : og_scorecard_format_threshold(row[:green])

    if row[:yellow].nil? && row[:green].nil?
      return tag.p('Thresholds are not configured for this metric yet.', class: 'mb-0 small')
    end

    ye = ERB::Util.html_escape(y_txt)
    ge = ERB::Util.html_escape(g_txt)

    items = if row[:direction] == :less
                [
                  "🔴 Red if above the yellow threshold (#{ye})",
                  "🟡 Yellow if between the green (#{ge}) and yellow (#{ye}) thresholds",
                  "🟢 Green if at or below the green threshold (#{ge})"
                ]
              else
                [
                  "🔴 Red if below the yellow threshold (#{ye})",
                  "🟡 Yellow if between the yellow (#{ye}) and green (#{ge}) thresholds",
                  "🟢 Green if at or above the green threshold (#{ge})"
                ]
              end

    tag.ul(class: 'mb-0 ps-3 small') do
      safe_join(items.map { |line| tag.li(line.html_safe, class: 'mb-1') })
    end
  end

  def og_scorecard_format_threshold(value)
    case value
    when Integer, Float then value.to_s
    else value.to_s
    end
  end
end
