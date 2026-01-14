module AssignmentsHelper
  def assignments_current_view_name
    return 'Assignment View' unless action_name
    
    # Check if we're in public view
    if request.path.include?('/public_maap/assignments/')
      return 'Public View'
    end
    
    # Check if we're in ability milestones view
    if request.path.include?('/ability_milestones')
      return 'Manage Ability Milestones'
    end
    
    # Check if we're in edit view
    if action_name == 'edit' && controller_name == 'assignments'
      return 'Edit Assignment'
    end
    
    # Check if we're in teammate view
    if @teammate.present? && request.path.include?('/teammates/')
      return 'Teammate View'
    end
    
    # Check if we're in person view
    if @person.present? && !@teammate.present? && request.path.include?('/people/')
      return 'Person View'
    end
    
    # Default to Organization View
    'Organization View'
  end

  def assignment_outcome_management_relationship_label(filter_value)
    return nil unless filter_value.present?
    
    case filter_value
    when 'direct_employee'
      'Actively a direct employee of the Assignment holder'
    when 'direct_manager'
      'Actively the direct manager of the Assignment holder'
    when 'no_relationship'
      'No managerial relationship with assignment holder'
    else
      filter_value.humanize
    end
  end

  def assignment_outcome_team_relationship_label(filter_value)
    return nil unless filter_value.present?
    
    case filter_value
    when 'same_team'
      'On the same team as the Assignment holder'
    when 'different_team'
      'Not on the same team as the Assignment holder'
    else
      filter_value.humanize
    end
  end

  def assignment_outcome_consumer_assignment_label(filter_value, assignment)
    return nil unless filter_value.present?
    
    consumer_assignments = assignment.consumer_assignments.order(:title)
    assignment_list = if consumer_assignments.any?
      consumer_assignments.map(&:title).join(', ')
    else
      'associated assignment that can be defined'
    end
    
    case filter_value
    when 'active_consumer'
      "Teammates who ARE taking on: #{assignment_list}"
    when 'not_consumer'
      "Teammates who ARE NOT taking on: #{assignment_list}"
    else
      filter_value.humanize
    end
  end
end
