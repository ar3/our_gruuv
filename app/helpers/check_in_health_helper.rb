module CheckInHealthHelper
  # Position health cell helpers
  def position_health_cell_class(status)
    case status
    when :alarm
      'bg-danger-subtle text-danger'
    when :in_progress
      'bg-warning text-dark'
    when :success
      'bg-success text-white'
    when :warning
      'bg-danger text-white'
    else
      ''
    end
  end

  def position_health_icon(status)
    case status
    when :alarm
      'bi-exclamation-triangle'
    when :in_progress
      'bi-tools'
    when :success
      'bi-check-circle'
    when :warning
      'bi-clock-history'
    else
      ''
    end
  end

  def position_health_status_text(health_data)
    status = health_data[:status]
    last_rating_date = health_data[:last_rating_date]
    open_check_in = health_data[:open_check_in]
    
    if status == :alarm
      'No check-in started'
    elsif open_check_in
      if open_check_in.employee_completed?
        'Check-in in progress'
      else
        'Check-in awaiting employee'
      end
    elsif status == :success
      "Rated #{time_ago_in_words(last_rating_date)} ago"
    elsif status == :warning
      "Rated #{time_ago_in_words(last_rating_date)} ago"
    else
      'Unknown status'
    end
  end

  def position_health_tooltip(health_data)
    status = health_data[:status]
    last_rating_date = health_data[:last_rating_date]
    days_since_rating = health_data[:days_since_rating]
    open_check_in = health_data[:open_check_in]
    open_check_in_started_on = health_data[:open_check_in_started_on]
    
    parts = []
    
    if status == :alarm
      parts << 'No official rating has ever been recorded'
    elsif last_rating_date
      exact_date = last_rating_date.strftime('%B %d, %Y')
      if status == :warning
        parts << "Last rated: #{exact_date} (#{days_since_rating} days ago)"
        parts << 'This is older than 90 days ago'
      else
        parts << "Last rated: #{exact_date} (#{days_since_rating} days ago)"
      end
    end
    
    if open_check_in
      if open_check_in_started_on
        parts << "Open check-in started: #{open_check_in_started_on.strftime('%B %d, %Y')}"
      end
      if health_data[:open_unacknowledged]
        parts << 'Check-in awaiting employee acknowledgment'
      end
    end
    
    parts.join('. ')
  end

  # Assignment health cell helpers
  def assignment_health_cell_class(status)
    case status
    when :alarm
      'bg-danger-subtle text-danger'
    when :in_progress
      'bg-warning text-dark'
    when :success
      'bg-success text-white'
    when :warning
      'bg-danger text-white'
    else
      ''
    end
  end

  def assignment_health_display(health_data)
    total = health_data[:total_count]
    completed = health_data[:completed_count]
    open_count = health_data[:open_count]
    unacknowledged = health_data[:unacknowledged_count]
    
    text = "#{completed}/#{total} completed"
    
    if open_count > 0
      text += " (#{open_count} open"
      if unacknowledged > 0
        text += ", #{unacknowledged} unacknowledged"
      end
      text += ")"
    end
    
    text
  end

  def assignment_health_tooltip(health_data)
    total = health_data[:total_count]
    completed = health_data[:completed_count]
    open_count = health_data[:open_count]
    unacknowledged = health_data[:unacknowledged_count]
    
    parts = []
    parts << "#{completed} of #{total} assignments have completed check-ins in the last 90 days"
    
    if open_count > 0
      parts << "#{open_count} open check-in#{'s' if open_count != 1}"
      if unacknowledged > 0
        parts << "#{unacknowledged} awaiting employee acknowledgment"
      end
    end
    
    parts.join('. ')
  end

  # Aspiration health cell helpers
  def aspiration_health_cell_class(status)
    case status
    when :alarm
      'bg-danger-subtle text-danger'
    when :in_progress
      'bg-warning text-dark'
    when :success
      'bg-success text-white'
    when :warning
      'bg-danger text-white'
    else
      ''
    end
  end

  def aspiration_health_display(health_data)
    total = health_data[:total_count]
    rated = health_data[:rated_count]
    open_count = health_data[:open_count]
    unacknowledged = health_data[:unacknowledged_count]
    
    if total == 0
      'No aspirations'
    else
      text = "#{rated}/#{total} rated"
      
      if open_count > 0
        text += " (#{open_count} open"
        if unacknowledged > 0
          text += ", #{unacknowledged} unacknowledged"
        end
        text += ")"
      end
      
      text
    end
  end

  def aspiration_health_tooltip(health_data)
    total = health_data[:total_count]
    rated = health_data[:rated_count]
    open_count = health_data[:open_count]
    unacknowledged = health_data[:unacknowledged_count]
    
    if total == 0
      'No aspirations defined for this organization'
    else
      parts = []
      parts << "#{rated} of #{total} aspirations have observation ratings in the last 90 days"
      
      if open_count > 0
        parts << "#{open_count} open check-in#{'s' if open_count != 1}"
        if unacknowledged > 0
          parts << "#{unacknowledged} awaiting employee acknowledgment"
        end
      end
      
      parts.join('. ')
    end
  end

  # Milestone health cell helpers
  def milestone_health_cell_class(status)
    case status
    when :alarm
      'bg-danger-subtle text-danger'
    when :in_progress
      'bg-warning text-dark'
    when :success
      'bg-success text-white'
    when :warning
      'bg-danger text-white'
    else
      ''
    end
  end

  def milestone_health_display(health_data)
    required = health_data[:required_count]
    attained = health_data[:attained_count]
    
    if required == 0
      'No requirements'
    else
      "#{attained}/#{required} attained"
    end
  end

  def milestone_health_tooltip(health_data)
    required = health_data[:required_count]
    attained = health_data[:attained_count]
    
    if required == 0
      'No milestone requirements from active assignments'
    else
      "#{attained} of #{required} required milestone#{'s' if required != 1} attained based on active assignments"
    end
  end

  # Cache-based stacked bar helpers (7 categories). No borders on segments.
  CHECK_IN_HEALTH_CATEGORY_CSS = {
    'red' => 'bg-danger',
    'orange' => 'bg-warning',
    'light_blue' => 'bg-info bg-opacity-75',
    'light_purple' => 'bg-primary bg-opacity-50',
    'light_green' => 'bg-success bg-opacity-75',
    'green' => 'bg-success',
    'neon_green' => 'check-in-health-neon-green'
  }.freeze

  # Human meaning of each category (for legend and tooltips)
  CHECK_IN_HEALTH_CATEGORY_MEANINGS = {
    'red' => 'No check-in by the manager in the past 90 days',
    'orange' => 'Older or in-progress check-in (not completed by manager in past 90 days)',
    'light_blue' => 'Employee completed; awaiting manager check-in in past 90 days',
    'light_purple' => 'Manager completed; awaiting employee in past 90 days',
    'light_green' => 'Both sides completed in past 90 days (not yet finalized)',
    'green' => 'Finalized check-in in past 90 days (awaiting employee acknowledgment)',
    'neon_green' => 'Finalized and acknowledged check-in in past 90 days'
  }.freeze

  def check_in_health_category_css(category)
    CHECK_IN_HEALTH_CATEGORY_CSS[category.to_s] || 'bg-light'
  end

  def check_in_health_category_meaning(category)
    CHECK_IN_HEALTH_CATEGORY_MEANINGS[category.to_s] || category.to_s.humanize
  end

  # Tooltip text for a bar segment: "X of Y <objects> <meaning>"
  def check_in_health_segment_tooltip(segment, total, object_name)
    count = segment[:count]
    category = segment[:category].to_s
    meaning = check_in_health_category_meaning(category)
    return meaning if total == 1 && object_name == 'position'
    "#{count} of #{total} #{object_name} #{meaning.downcase}"
  end

  # For milestones: green = earned, red = not earned
  def check_in_health_milestone_segment_tooltip(segment, total)
    count = segment[:count]
    if segment[:category].to_s == 'green'
      "#{count} of #{total} required milestones attained"
    else
      "#{total - count} of #{total} required milestones not yet attained"
    end
  end

  # Items array (assignments or aspirations) -> hash of category counts for stacked bar
  def check_in_health_category_counts(items)
    items = Array(items)
    return { 'red' => 1 } if items.empty?
    counts = items.group_by { |i| i['category'].to_s }.transform_values(&:count)
    %w[red orange light_blue light_purple light_green green neon_green].index_with { |c| counts[c].to_i }
  end

  # Single position item -> same shape for one segment
  def check_in_health_position_segment(position_item)
    return { 'red' => 1 } if position_item.blank?
    cat = position_item['category'].to_s.presence || 'red'
    { cat => 1 }
  end

  # Milestones: earned vs not earned (for stacked bar: earned = green, not_earned = red)
  def check_in_health_milestone_segments(milestones_payload)
    total = milestones_payload['total_required'].to_i
    earned = milestones_payload['earned_count'].to_i
    return {} if total.zero?
    { 'green' => earned, 'red' => total - earned }
  end

  # Left-to-right order for stacked bars: red → neon green
  CHECK_IN_HEALTH_BAR_ORDER = %w[red orange light_blue light_purple light_green green neon_green].freeze

  # Render horizontal stacked bar from segment hash (category => count). Total = sum of counts.
  # Segments are always ordered red (left) → neon green (right).
  def check_in_health_stacked_bar_segments(segment_counts)
    total = segment_counts.values.sum.to_f
    return [] if total.zero?
    CHECK_IN_HEALTH_BAR_ORDER.filter_map do |category|
      count = segment_counts[category].to_i
      next if count.zero?
      pct = (count / total * 100).round(1)
      { category: category, pct: pct, count: count, css: check_in_health_category_css(category) }
    end
  end

  # Check-ins-only completion rate and per-area percentages (position, assignments, aspirations). Excludes milestones.
  # Returns nil if cache is nil; otherwise { completion_rate:, position_pct:, assignments_pct:, aspirations_pct: }.
  def check_in_health_completion_rate_and_breakdown(cache)
    return nil unless cache
    pts = cache.completion_points
    pos_pts = pts[:position].to_f
    assign_pts = pts[:assignments].to_f
    aspir_pts = pts[:aspirations].to_f
    pos_max = 4.0
    assign_max = (cache.payload_assignments.size * 4).to_f
    assign_max = 4.0 if cache.payload_assignments.empty?
    aspir_max = (cache.payload_aspirations.size * 4).to_f
    aspir_max = 4.0 if cache.payload_aspirations.empty?
    total_pts = pos_pts + assign_pts + aspir_pts
    total_max = pos_max + assign_max + aspir_max
    rate = total_max.positive? ? (total_pts / total_max * 100).round(1) : 0
    {
      completion_rate: rate,
      position_pct: pos_max.positive? ? (pos_pts / pos_max * 100).round(0) : 0,
      assignments_pct: assign_max.positive? ? (assign_pts / assign_max * 100).round(0) : 0,
      aspirations_pct: aspir_max.positive? ? (aspir_pts / aspir_max * 100).round(0) : 0
    }
  end

  # Bootstrap text class for completion rate: success (≥80%), info (50–80%), warning (<50%).
  def check_in_health_rate_text_class(rate)
    return 'text-secondary' if rate.nil?
    if rate >= 80
      'text-success'
    elsif rate >= 50
      'text-info'
    else
      'text-warning'
    end
  end

  # General helpers
  def health_status_badge_class(status)
    case status
    when :alarm
      'badge bg-danger-subtle text-danger'
    when :in_progress
      'badge bg-warning text-dark'
    when :success
      'badge bg-success'
    when :warning
      'badge bg-danger'
    else
      'badge bg-secondary'
    end
  end

  def health_status_text(status)
    status.to_s.humanize.titleize
  end
end









