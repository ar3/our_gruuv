module CheckInHelper
  # Reference the single source of truth from EmploymentTenure
  def position_rating_display(rating)
    return 'Not Rated' if rating.nil?
    data = EmploymentTenure::POSITION_RATINGS[rating]
    return 'Not Rated' if data.nil?
    "#{data[:emoji]} #{data[:label]}"
  end
  
  def position_rating_options
    EmploymentTenure::POSITION_RATINGS.map do |value, data|
      ["#{data[:emoji]} #{data[:label]} - #{data[:description]}", value]
    end
  end
  
  ASSIGNMENT_RATINGS = {
    'working_to_meet' => { emoji: '🟡', label: 'Working to Meet' },
    'meeting' => { emoji: '🔵', label: 'Meeting' },
    'exceeding' => { emoji: '🟢', label: 'Exceeding' }
  }.freeze
  
  ASPIRATION_RATINGS = {
    'working_to_meet' => { emoji: '🟡', label: 'Working to Meet' },
    'meeting' => { emoji: '🔵', label: 'Meeting' },
    'exceeding' => { emoji: '🟢', label: 'Exceeding' }
  }.freeze
  
  def aspiration_rating_display(rating)
    return 'Not Rated' if rating.nil?
    data = ASPIRATION_RATINGS[rating]
    "#{data[:emoji]} #{data[:label]}"
  end
  
  def aspiration_rating_options
    ASPIRATION_RATINGS.map do |value, data|
      ["#{data[:emoji]} #{data[:label]}", value]
    end
  end
  
  def assignment_rating_display(rating)
    return 'Not Rated' if rating.nil?
    data = ASSIGNMENT_RATINGS[rating]
    "#{data[:emoji]} #{data[:label]}"
  end
  
  def assignment_rating_options
    ASSIGNMENT_RATINGS.map do |value, data|
      ["#{data[:emoji]} #{data[:label]}", value]
    end
  end
  
  def check_in_status_badge(check_in)
    return content_tag(:span, '📝 In Progress', class: 'badge badge-secondary') unless check_in
    
    if check_in.officially_completed?
      content_tag(:span, '✅ Complete', class: 'badge badge-success')
    elsif check_in.ready_for_finalization?
      content_tag(:span, '⏳ Ready to Finalize', class: 'badge badge-warning')
    elsif check_in.employee_completed? && !check_in.manager_completed?
      content_tag(:span, '⏳ Waiting for Manager', class: 'badge badge-info')
    elsif check_in.manager_completed? && !check_in.employee_completed?
      content_tag(:span, '⏳ Waiting for Employee', class: 'badge badge-info')
    else
      content_tag(:span, '📝 In Progress', class: 'badge badge-secondary')
    end
  end
  
  def partial_exists?(partial_name)
    lookup_context.exists?(partial_name, [], true)
  end

  # Popover content for latest finalized check-ins
  def latest_position_check_in_popover_content(teammate)
    latest = PositionCheckIn.latest_finalized_for(teammate)
    return "No completed check-ins yet" unless latest
    
    content = []
    content << "<strong>Finalized:</strong> #{latest.official_check_in_completed_at.strftime('%m/%d/%Y')}"
    content << "<strong>Rating:</strong> #{position_rating_display(latest.official_rating)}"
    content << "<strong>By:</strong> #{latest.finalized_by.display_name}" if latest.finalized_by
    content << "<br><em>#{latest.shared_notes}</em>" if latest.shared_notes.present?
    content.join('<br>')
  end

  def latest_assignment_check_in_popover_content(teammate, assignment)
    latest = AssignmentCheckIn.latest_finalized_for(teammate, assignment)
    return "No completed check-ins yet" unless latest
    
    content = []
    content << "<strong>Finalized:</strong> #{latest.official_check_in_completed_at.strftime('%m/%d/%Y')}"
    content << "<strong>Rating:</strong> #{assignment_rating_display(latest.official_rating)}"
    content << "<strong>By:</strong> #{latest.finalized_by.display_name}" if latest.finalized_by
    content << "<br><em>#{latest.shared_notes}</em>" if latest.shared_notes.present?
    content.join('<br>')
  end

  def latest_aspiration_check_in_popover_content(teammate, aspiration)
    latest = AspirationCheckIn.latest_finalized_for(teammate, aspiration)
    return "No completed check-ins yet" unless latest
    
    content = []
    content << "<strong>Finalized:</strong> #{latest.official_check_in_completed_at.strftime('%m/%d/%Y')}"
    content << "<strong>Rating:</strong> #{aspiration_rating_display(latest.official_rating)}"
    content << "<strong>By:</strong> #{latest.finalized_by.display_name}" if latest.finalized_by
    content << "<br><em>#{latest.shared_notes}</em>" if latest.shared_notes.present?
    content.join('<br>')
  end
end




