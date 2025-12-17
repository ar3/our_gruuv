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
end
