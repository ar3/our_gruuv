module CheckInHealthHelper
  include CheckInsHealthEngagementHealthHelper
  include CheckInsHealthBarsHelper
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

  def engagement_health_clarity_breakdown(records)
    EngagementHealth::ClarityMetrics.breakdown(records)
  end

  def engagement_health_clarity_popover_table(records)
    EngagementHealth::ClarityMetrics.popover_table_data(records).presence
  end

  def engagement_health_clarity_breakdown_for_teammate(organization:, teammate:)
    records = EngagementHealth::ClarityMetrics.records_for_teammate(
      organization: organization,
      teammate_id: teammate.id
    )
    engagement_health_clarity_breakdown(records)
  end

  def engagement_health_clarity_popover_table_for_teammate(organization:, teammate:)
    records = EngagementHealth::ClarityMetrics.records_for_teammate(
      organization: organization,
      teammate_id: teammate.id
    )
    engagement_health_clarity_popover_table(records)
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

  # Footnote for shared/clarity_popover_table.
  def check_in_health_clarity_popover_caption
    format(
      "Employee and manager columns reflect in-progress workflow completion; Together is the share of items with Healthy Gruuv Health status (finalized within %{healthy} days).",
      healthy: EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS
    )
  end
end









