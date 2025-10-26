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
    if teammate.organization == @organization
      content_tag :span, teammate.organization.name, class: "text-primary fw-bold"
    else
      content_tag :span, teammate.organization.display_name, class: "text-muted"
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
    current_params = params.to_unsafe_h.dup
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
    organization_employees_path(@organization, current_params.except(:controller, :action))
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
    teammate = person.teammates.find_by(organization: organization)
    return { position: [], assignments: [], aspirations: [], milestones: [], ready_for_finalization: [], needs_manager_completion: [], needs_employee_completion: [], all_complete: [] } unless teammate

    # Position check-ins
    position_check_ins = teammate.employment_tenures.active
                                 .flat_map(&:position_check_ins)
                                 .select(&:open?)

    # Assignment check-ins
    assignment_check_ins = teammate.assignment_tenures.active
                                  .flat_map(&:assignment_check_ins)
                                  .select(&:open?)

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
    case check_in.class.name
    when 'PositionCheckIn'
      'Position'
    when 'AssignmentCheckIn'
      check_in.assignment&.name || 'Assignment'
    when 'AspirationCheckIn'
      check_in.aspiration&.name || 'Aspiration'
    else
      check_in.class.name.humanize
    end
  end
end