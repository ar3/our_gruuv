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