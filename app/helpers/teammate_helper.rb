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
end