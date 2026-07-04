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

  REQUIRED_CLARITY_BAR_ORDER = %w[obscured blurred clear crystal_clear].freeze
  REQUIRED_CLARITY_CSS = {
    'obscured' => 'bg-danger',
    'blurred' => 'bg-warning',
    'clear' => 'bg-success',
    'crystal_clear' => 'check-in-health-neon-green'
  }.freeze
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

  def required_check_in_category_css(clarity_level)
    REQUIRED_CLARITY_CSS[clarity_level.to_s] || 'bg-danger'
  end

  def required_check_in_category_counts(items)
    counts = { 'obscured' => 0, 'blurred' => 0, 'clear' => 0, 'crystal_clear' => 0 }
    Array(items).each do |item|
      level = item['clarity_level'].to_s
      normalized = counts.key?(level) ? level : 'obscured'
      counts[normalized] += 1
    end
    counts
  end

  def required_check_in_stacked_bar_segments(segment_counts)
    total = segment_counts.values.sum.to_f
    return [] if total.zero?

    REQUIRED_CLARITY_BAR_ORDER.filter_map do |clarity_level|
      count = segment_counts[clarity_level].to_i
      next if count.zero?

      pct = (count / total * 100).round(1)
      {
        category: clarity_level,
        pct: pct,
        count: count,
        css: required_check_in_category_css(clarity_level)
      }
    end
  end

  def required_check_in_segment_tooltip(segment, total, object_name)
    label = segment[:category].to_s.humanize.downcase
    meaning = required_check_in_clarity_meaning(segment[:category])
    count = segment[:count].to_i
    "#{count} of #{total} required #{object_name} are #{label}, meaning #{meaning}"
  end

  def required_check_in_items_for(cache, type)
    required = cache&.payload_required_check_ins || {}
    Array(required[type.to_s])
  end

  def required_check_ins_all_clear?(cache)
    required = cache&.payload_required_check_ins || {}
    items = Array(required['position']) + Array(required['assignments']) + Array(required['aspirations'])
    return true if items.empty?

    items.all? { |item| %w[clear crystal_clear].include?(item['clarity_level'].to_s) }
  end

  def required_check_ins_most_urgent(cache)
    required = cache&.payload_required_check_ins || {}
    items = Array(required['position']) + Array(required['assignments']) + Array(required['aspirations'])
    return nil if items.empty?

    items.min_by do |item|
      finalized = CheckIns::RequiredCheckInUrgencySort.parse_iso8601(item['last_finalized_at'])
      CheckIns::RequiredCheckInUrgencySort.sort_tuple(
        item['clarity_level'].to_s,
        item['type'].to_s,
        finalized,
        item['latest_finalized_rating']
      )
    end
  end

  def required_check_in_alert_data(cache:, organization:, teammate:)
    return { all_clear: true, message: 'continuous clarity achieved', url: nil } if required_check_ins_all_clear?(cache)

    urgent = required_check_ins_most_urgent(cache)
    return { all_clear: true, message: 'continuous clarity achieved', url: nil } if urgent.blank?

    item_type = urgent['type'].to_s
    item_name = urgent['name'].presence || item_type.humanize.downcase
    clarity_level = urgent['clarity_level'].to_s
    clarity_label = clarity_level.humanize.downcase
    clarity_meaning = required_check_in_clarity_meaning(clarity_level)
    message = "Consider checking in on: #{item_name} (#{clarity_label}, meaning #{clarity_meaning})"
    {
      all_clear: false,
      message: message,
      url: required_check_in_item_url(
        organization: organization,
        teammate: teammate,
        item_type: item_type,
        item_id: urgent['item_id']
      )
    }
  end

  def required_check_in_item_url(organization:, teammate:, item_type:, item_id:)
    case item_type.to_s
    when 'aspiration'
      organization_teammate_aspiration_path(organization, teammate, item_id)
    when 'assignment'
      organization_teammate_assignment_path(organization, teammate, item_id)
    when 'position'
      position_check_in_organization_teammate_path(organization, teammate)
    else
      organization_company_teammate_check_ins_path(organization, teammate)
    end
  end

  def required_check_in_clarity_meaning(clarity_level)
    case clarity_level.to_s
    when 'crystal_clear'
      "check-ins were completed within #{CheckInBehavior::CLARITY_CRYSTAL_CLEAR_DAYS} days"
    when 'clear'
      "check-ins were completed between #{CheckInBehavior::CLARITY_CRYSTAL_CLEAR_DAYS + 1}-#{CheckInBehavior::CLARITY_CLEAR_DAYS} days ago"
    when 'blurred'
      "check-ins were completed between #{CheckInBehavior::CLARITY_CLEAR_DAYS + 1}-#{CheckInBehavior::CLARITY_BLURRED_DAYS} days ago"
    else
      "no check-ins were completed in the last #{CheckInBehavior::CLARITY_BLURRED_DAYS} days"
    end
  end

  # Check-ins-only completion rate and per-area percentages (position, assignments, aspirations). Excludes milestones.
  # Returns nil if cache is nil; otherwise { completion_rate:, position_pct:, assignments_pct:, aspirations_pct: }.
  def check_in_health_completion_rate_and_breakdown(cache)
    CheckInHealthCompletionRate.completion_breakdown_for_cache(cache)
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

  # Table data for single-item header popover: rows = position, assignments, aspirations;
  # columns = employee, manager, together. Each cell = % "current" if that side completed within
  # CheckInBehavior::CLARITY_CLEAR_DAYS (clear threshold; see popover footnote vs headline rate).
  # Returns nil if cache is nil; otherwise { position: { employee:, manager:, together: }, assignments: {...}, aspirations: {...} } with 0–100 values.
  def single_item_health_popover_table(cache)
    return nil unless cache

    cutoff = CheckInBehavior::CLARITY_CLEAR_DAYS.days.ago
    healthy = lambda { |date_str|
      return false unless date_str.present?
      t = Time.zone.parse(date_str.to_s) rescue nil
      t && t >= cutoff
    }

    pos = cache.payload_position
    pos_emp = pos['employee_completed_at'].present? ? (healthy.call(pos['employee_completed_at']) ? 100 : 0) : 0
    pos_mgr = pos['manager_completed_at'].present? ? (healthy.call(pos['manager_completed_at']) ? 100 : 0) : 0
    pos_together = pos['official_check_in_completed_at'].present? ? (healthy.call(pos['official_check_in_completed_at']) ? 100 : 0) : 0

    assignments = cache.payload_assignments
    n_assign = assignments.size
    if n_assign.zero?
      assign_emp = assign_mgr = assign_together = 0
    else
      assign_emp = (assignments.count { |i| healthy.call(i['employee_completed_at']) }.to_f / n_assign * 100).round(0)
      assign_mgr = (assignments.count { |i| healthy.call(i['manager_completed_at']) }.to_f / n_assign * 100).round(0)
      assign_together = (assignments.count { |i| healthy.call(i['official_check_in_completed_at']) }.to_f / n_assign * 100).round(0)
    end

    aspirations = cache.payload_aspirations
    n_aspir = aspirations.size
    if n_aspir.zero?
      aspir_emp = aspir_mgr = aspir_together = 0
    else
      aspir_emp = (aspirations.count { |i| healthy.call(i['employee_completed_at']) }.to_f / n_aspir * 100).round(0)
      aspir_mgr = (aspirations.count { |i| healthy.call(i['manager_completed_at']) }.to_f / n_aspir * 100).round(0)
      aspir_together = (aspirations.count { |i| healthy.call(i['official_check_in_completed_at']) }.to_f / n_aspir * 100).round(0)
    end

    {
      position: { employee: pos_emp, manager: pos_mgr, together: pos_together },
      assignments: { employee: assign_emp, manager: assign_mgr, together: assign_together },
      aspirations: { employee: aspir_emp, manager: aspir_mgr, together: aspir_together }
    }
  end

  # Footnote for shared/clarity_popover_table (popover uses clear window; headline % uses blurred window in cache).
  def check_in_health_clarity_popover_caption
    format(
      "The above calculations are based on check-ins that have been completed in the last %{clear} days, " \
      "but the overall clarity percentage is based on check-ins that have been completed in the last %{blurred} days.",
      clear: CheckInBehavior::CLARITY_CLEAR_DAYS,
      blurred: CheckInBehavior::CLARITY_BLURRED_DAYS
    )
  end
end









