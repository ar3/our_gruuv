module TeammateHelper
  def employment_status_badge(teammate)
    status = TeammateStatus.new(teammate)
    
    content_tag :span, 
                class: "badge #{status.badge_class}", 
                "data-bs-toggle" => "tooltip", 
                "data-bs-title" => status.tooltip_content do
      content_tag(:i, "", class: "bi #{status.icon_class} me-1") + status.status_name
    end
  end

  def employment_status_progress_bar(teammate)
    status = TeammateStatus.new(teammate)
    
    content_tag :div, 
                class: "employment-status-progress", 
                "data-bs-toggle" => "tooltip", 
                "data-bs-title" => status.tooltip_content do
      content_tag(:div, class: "d-flex justify-content-between align-items-center mb-1") do
        content_tag(:small, status.status_name, class: "text-muted") +
        content_tag(:small, "#{status.progress_percentage}%", class: "text-muted")
      end +
      content_tag(:div, class: "progress", style: "height: 6px;") do
        content_tag(:div, "", 
                   class: "progress-bar #{status.badge_class}", 
                   style: "width: #{status.progress_percentage}%", 
                   role: "progressbar", 
                   "aria-valuenow" => status.progress_percentage, 
                   "aria-valuemin" => "0", 
                   "aria-valuemax" => "100")
      end
    end
  end

  def teammate_organization_display(teammate)
    return '' unless teammate&.person && @organization
    
    # Get the company (root organization)
    company = @organization.root_company || @organization
    
    # Find all teammates for this person within the company hierarchy (excluding the company itself)
    associated_orgs = teammate.person.teammates
                              .joins(:organization)
                              .where(organization: company.self_and_descendants)
                              .where.not(organization: company) # Exclude company
                              .includes(:organization)
                              .map(&:organization)
                              .uniq
                              .sort_by(&:name)
    
    if associated_orgs.any?
      # Display as comma-separated list
      org_names = associated_orgs.map(&:name).join(', ')
      content_tag :span, org_names, class: "text-muted"
    else
      # If no departments/teams, show empty or a message
      content_tag :span, '—', class: "text-muted"
    end
  end

  def teammate_permissions_badges(teammate)
    badges = []
    
    if teammate.can_manage_employment?
      badges << content_tag(:span, "Employment", class: "badge bg-info me-1")
    end
    
    if teammate.can_create_employment?
      badges << content_tag(:span, "Create", class: "badge bg-primary me-1")
    end
    
    if teammate.can_manage_maap?
      badges << content_tag(:span, "MAAP", class: "badge bg-success me-1")
    end
    
    badges.any? ? badges.join.html_safe : content_tag(:span, "No special permissions", class: "text-muted small")
  end

  def teammate_current_position(teammate)
    current_tenure = teammate.employment_tenures.active.first
    if current_tenure&.position
      content_tag :span, current_tenure.position.display_name, class: "text-dark"
    else
      content_tag :span, "No position", class: "text-muted"
    end
  end

  # Filter and sort helper methods
  def filter_display_name(filter_name, filter_value)
    case filter_name.to_s
    when 'status'
      case filter_value.to_s
      when 'follower' then 'Followers'
      when 'huddler' then 'Huddlers'
      when 'unassigned_employee' then 'Unassigned'
      when 'assigned_employee' then 'Active Employees'
      when 'terminated' then 'Terminated'
      else filter_value.to_s.humanize
      end
    when 'organization_id'
      org = Organization.find_by(id: filter_value)
      org ? org.name : "Organization #{filter_value}"
    when 'permission'
      case filter_value.to_s
      when 'employment_mgmt' then 'Employment Management'
      when 'employment_create' then 'Employment Creation'
      when 'maap_mgmt' then 'MAAP Management'
      else filter_value.to_s.humanize
      end
    when 'manager_filter'
      case filter_value.to_s
      when 'direct_reports' then 'My Direct Reports'
      else filter_value.to_s.humanize
      end
    else
      filter_value.to_s.humanize
    end
  end

  def clear_filter_url(filter_name, filter_value)
    return '' if filter_name.nil?
    return '' if filter_value.nil? # Return empty string for nil values
    
    # Handle both ActionController::Parameters and Hash
    current_params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h.dup : params.dup
    case filter_name.to_s
    when 'status'
      current_params[:status] = Array(current_params[:status]) - [filter_value]
      current_params[:status] = nil if current_params[:status].empty?
    when 'organization_id'
      current_params[:organization_id] = nil
    when 'permission'
      current_params[:permission] = Array(current_params[:permission]) - [filter_value]
      current_params[:permission] = nil if current_params[:permission].empty?
    when 'manager_filter'
      current_params[:manager_filter] = nil
    end
    
    # Get organization from instance variable
    organization = @organization
    return '' if organization.nil?
    
    # Remove nil values and controller/action keys for cleaner URL
    clean_params = current_params.except(:controller, :action).compact
    organization_employees_path(organization, clean_params)
  end

  def sort_icon(sort_field)
    case sort_field
    when 'name_asc', 'name_desc'
      'bi-sort-alpha-down'
    when 'status'
      'bi-sort-down'
    when 'organization'
      'bi-building'
    when 'employment_date'
      'bi-calendar'
    else
      'bi-sort-down'
    end
  end

  def view_type_icon(view_type)
    case view_type
    when 'table'
      'bi-table'
    when 'cards'
      'bi-grid'
    when 'list'
      'bi-list'
    else
      'bi-table'
    end
  end

  def teammate_employment_dates(teammate)
    if teammate.first_employed_at
      started = teammate.first_employed_at.strftime('%b %Y')
      if teammate.last_terminated_at
        ended = teammate.last_terminated_at.strftime('%b %Y')
        "#{started} - #{ended}"
      else
        "#{started} - Present"
      end
    else
      "Not employed"
    end
  end

  # Check-in status helper methods for manager view
  def overall_employee_status(person, organization)
    return 'unknown' if person.nil? || organization.nil?
    
    teammate = person.teammates.find_by(organization: organization)
    return 'unknown' unless teammate

    # Calculate overall status based on check-in states
    check_ins = check_ins_for_employee(person, organization)
    
    if check_ins[:ready_for_finalization].any?
      'ready_for_finalization'
    elsif check_ins[:needs_manager_completion].any?
      'needs_manager_completion'
    elsif check_ins[:needs_employee_completion].any?
      'needs_employee_completion'
    elsif check_ins[:all_complete].any?
      'all_complete'
    else
      'no_check_ins'
    end
  end

  def overall_status_badge(status)
    case status
    when 'ready_for_finalization'
      content_tag(:span, 'Ready to Finalize', class: 'badge bg-warning')
    when 'needs_manager_completion'
      content_tag(:span, 'Needs Manager Input', class: 'badge bg-danger')
    when 'needs_employee_completion'
      content_tag(:span, 'Needs Employee Input', class: 'badge bg-info')
    when 'all_complete'
      content_tag(:span, 'All Complete', class: 'badge bg-success')
    when 'no_check_ins'
      content_tag(:span, 'No Check-ins', class: 'badge bg-secondary')
    else
      content_tag(:span, 'Unknown', class: 'badge bg-secondary')
    end
  end

  def check_ins_for_employee(person, organization)
    return { position: [], assignments: [], aspirations: [], milestones: [], ready_for_finalization: [], needs_manager_completion: [], needs_employee_completion: [], all_complete: [] } if person.nil? || organization.nil?
    
    teammate = person.teammates.find_by(organization: organization)
    return { position: [], assignments: [], aspirations: [], milestones: [], ready_for_finalization: [], needs_manager_completion: [], needs_employee_completion: [], all_complete: [] } unless teammate

    # Position check-ins
    position_check_ins = teammate.employment_tenures.active
                                 .flat_map(&:position_check_ins)
                                 .select(&:open?)

    # Assignment check-ins - query directly from teammate since assignment_check_in belongs_to teammate
    assignment_check_ins = teammate.assignment_check_ins.open

    # Aspiration check-ins
    aspiration_check_ins = teammate.aspiration_check_ins.open

    # Milestone progress (simplified for now)
    milestone_progress = teammate.teammate_milestones.joins(:ability)
                                .where(abilities: { organization: organization })

    all_check_ins = position_check_ins + assignment_check_ins + aspiration_check_ins

    {
      position: position_check_ins,
      assignments: assignment_check_ins,
      aspirations: aspiration_check_ins,
      milestones: milestone_progress,
      ready_for_finalization: all_check_ins.select(&:ready_for_finalization?),
      needs_manager_completion: all_check_ins.select { |ci| ci.manager_open_employee_complete? },
      needs_employee_completion: all_check_ins.select { |ci| ci.manager_complete_employee_open? },
      all_complete: all_check_ins.select { |ci| ci.both_open? }
    }
  end

  def ready_for_finalization_count(person, organization)
    check_ins_for_employee(person, organization)[:ready_for_finalization].count
  end

  def pending_acknowledgements_count(person, organization)
    MaapSnapshot.for_employee(person)
                .for_company(organization)
                .where.not(effective_date: nil)
                .where(employee_acknowledged_at: nil)
                .count
  end

  def check_in_status_badge(check_in)
    return content_tag(:span, 'Unknown', class: 'badge bg-secondary') if check_in.nil?
    
    case check_in.completion_state
    when :both_complete
      content_tag(:span, 'Ready', class: 'badge bg-warning')
    when :manager_complete_employee_open
      content_tag(:span, 'Employee', class: 'badge bg-info')
    when :manager_open_employee_complete
      content_tag(:span, 'Manager', class: 'badge bg-danger')
    when :both_open
      content_tag(:span, 'Draft', class: 'badge bg-secondary')
    else
      content_tag(:span, 'Unknown', class: 'badge bg-secondary')
    end
  end

  def check_in_type_name(check_in)
    return 'Unknown' if check_in.nil?
    
    case check_in.class.name
    when 'PositionCheckIn'
      'Position'
    when 'AssignmentCheckIn'
      check_in.assignment&.name || 'Assignment'
    when 'AspirationCheckIn'
      check_in.aspiration&.name || 'Aspiration'
    else
      check_in.class.name.gsub(/CheckIn/, ' Check In').humanize
    end
  end

  # Freshness categorization and summary methods for direct reports view
  def categorize_check_ins_by_freshness(check_ins)
    fresh = []
    stale_active = []
    stale_inactive = []
    
    check_ins.each do |check_in|
      if check_in.official_check_in_completed_at.nil?
        # Never finalized - treat as stale_inactive
        stale_inactive << check_in
      elsif check_in.official_check_in_completed_at > 90.days.ago
        fresh << check_in
      elsif check_in.employee_completed_at.present? || check_in.manager_completed_at.present?
        stale_active << check_in
      else
        stale_inactive << check_in
      end
    end
    
    { fresh: fresh, stale_active: stale_active, stale_inactive: stale_inactive }
  end

  def check_in_freshness_summary(check_ins)
    return nil if check_ins.empty?
    
    categorized = categorize_check_ins_by_freshness(check_ins)
    total = check_ins.count
    
    {
      fresh_count: categorized[:fresh].count,
      fresh_percentage: (categorized[:fresh].count * 100.0 / total).round(0),
      stale_active_count: categorized[:stale_active].count,
      stale_active_percentage: (categorized[:stale_active].count * 100.0 / total).round(0),
      stale_inactive_count: categorized[:stale_inactive].count,
      stale_inactive_percentage: (categorized[:stale_inactive].count * 100.0 / total).round(0)
    }
  end

  def render_freshness_progress_bar(summary)
    return content_tag(:small, 'No check-ins', class: 'text-muted') if summary.nil?
    
    # Build progress bar with three segments
    fresh_bar = content_tag(:div, '', 
      class: 'progress-bar bg-success', 
      style: "width: #{summary[:fresh_percentage]}%",
      title: "#{summary[:fresh_count]} fresh (#{summary[:fresh_percentage]}%)")
    
    stale_active_bar = content_tag(:div, '', 
      class: 'progress-bar bg-info', 
      style: "width: #{summary[:stale_active_percentage]}%",
      title: "#{summary[:stale_active_count]} stale/active (#{summary[:stale_active_percentage]}%)")
    
    stale_inactive_bar = content_tag(:div, '', 
      class: 'progress-bar bg-warning', 
      style: "width: #{summary[:stale_inactive_percentage]}%",
      title: "#{summary[:stale_inactive_count]} stale/inactive (#{summary[:stale_inactive_percentage]}%)")
    
    content_tag(:div, fresh_bar + stale_active_bar + stale_inactive_bar, class: 'progress', style: 'height: 20px;')
  end

  def finalization_summary_by_type(check_ins)
    position_ready = check_ins[:position].select(&:ready_for_finalization?)
    assignment_ready = check_ins[:assignments].select(&:ready_for_finalization?)
    aspiration_ready = check_ins[:aspirations].select(&:ready_for_finalization?)
    
    {
      position: position_ready.count,
      assignments: assignment_ready.count,
      aspirations: aspiration_ready.count,
      total: position_ready.count + assignment_ready.count + aspiration_ready.count
    }
  end

  def acknowledgement_summary_by_type(person, organization)
    # MaapSnapshots don't have explicit type fields, so we'll infer from change_type
    snapshots = MaapSnapshot.for_employee(person)
                            .for_company(organization)
                            .where.not(effective_date: nil)
                            .where(employee_acknowledged_at: nil)
    
    position_count = snapshots.where(change_type: 'position_tenure').count
    assignment_count = snapshots.where(change_type: 'assignment_management').count
    aspiration_count = snapshots.where(change_type: 'aspiration_management').count
    milestone_count = snapshots.where(change_type: 'milestone_management').count
    bulk_count = snapshots.where(change_type: ['bulk_update', 'bulk_check_in_finalization']).count
    
    {
      position: position_count,
      assignments: assignment_count,
      aspirations: aspiration_count,
      milestones: milestone_count,
      bulk: bulk_count,
      total: snapshots.count
    }
  end

  def available_presets_for_select(organization, current_person)
    presets = []
    
    # My Direct Reports - Check-in Status Style 1
    if current_person&.has_direct_reports?(organization)
      presets << ['My Direct Reports - Check-in Status Style 1', 'my_direct_reports_check_in_status_1']
    end
    
    # My Direct Reports - Check-in Status Style 2
    can_manage = if respond_to?(:policy) && current_company_teammate&.organization == organization
      policy(organization).manage_employment?
    elsif current_person
      teammate = current_person.teammates.find_by(organization: organization)
      teammate&.can_manage_employment? || false
    else
      false
    end
    if current_person&.has_direct_reports?(organization) && can_manage
      presets << ['My Direct Reports - Check-in Status Style 2', 'my_direct_reports_check_in_status_2']
    end
    
    # All Employees - Check-in Status Style 1
    presets << ['All Employees - Check-in Status Style 1', 'all_employees_check_in_status_1']
    
    # All Employees - Check-in Status Style 2
    if can_manage
      presets << ['All Employees - Check-in Status Style 2', 'all_employees_check_in_status_2']
    end
    
    presets
  end

  def calculate_tenure_distribution(teammates)
    less_than_one = 0
    one_to_two = 0
    two_to_five = 0
    five_to_ten = 0
    ten_plus = 0
    
    teammates.each do |teammate|
      next unless teammate.first_employed_at
      
      tenure_years = (Date.current - teammate.first_employed_at.to_date).to_f / 365.25
      
      if tenure_years < 1
        less_than_one += 1
      elsif tenure_years < 2
        one_to_two += 1
      elsif tenure_years < 5
        two_to_five += 1
      elsif tenure_years < 10
        five_to_ten += 1
      else
        ten_plus += 1
      end
    end
    
    {
      less_than_one_year: less_than_one,
      one_to_two_years: one_to_two,
      two_to_five_years: two_to_five,
      five_to_ten_years: five_to_ten,
      ten_plus_years: ten_plus
    }
  end

  def calculate_location_distribution(teammates)
    state_counts = Hash.new(0)
    
    teammates.each do |teammate|
      primary_address = teammate.person.addresses.primary.first
      state = primary_address&.state_province
      state_counts[state] += 1
    end
    
    # Separate states with multiple employees from those with single employee
    states_multiple = state_counts.select { |_, count| count > 1 }.sort_by { |_, count| -count }
    states_single = state_counts.select { |_, count| count == 1 }.keys.sort
    
    {
      states_multiple: states_multiple,
      states_single: states_single
    }
  end

  # Debug helper methods
  def debug_boolean_badge(value)
    if value == true
      content_tag(:span, '✓ TRUE', class: 'badge bg-success')
    elsif value == false
      content_tag(:span, '✗ FALSE', class: 'badge bg-danger')
    else
      content_tag(:span, value.to_s, class: 'badge bg-secondary')
    end
  end

  def debug_warning_badge(warning)
    case warning[:type]
    when 'error'
      badge_class = 'bg-danger'
      icon = 'bi-x-circle'
    when 'warning'
      badge_class = 'bg-warning'
      icon = 'bi-exclamation-triangle'
    when 'info'
      badge_class = 'bg-info'
      icon = 'bi-info-circle'
    else
      badge_class = 'bg-secondary'
      icon = 'bi-question-circle'
    end
    
    content_tag(:div, class: "alert alert-#{warning[:type] == 'error' ? 'danger' : warning[:type]} mb-2") do
      content_tag(:i, '', class: "#{icon} me-2") +
      content_tag(:strong, warning[:message]) +
      content_tag(:div, warning[:details], class: 'small mt-1')
    end
  end

  def debug_format_value(value)
    case value
    when true, false
      debug_boolean_badge(value)
    when nil
      content_tag(:span, 'nil', class: 'text-muted fst-italic')
    when String
      content_tag(:code, value)
    when Integer, Float
      content_tag(:code, value.to_s)
    when Time, DateTime, Date
      content_tag(:code, value.to_s)
    else
      content_tag(:code, value.inspect)
    end
  end
end