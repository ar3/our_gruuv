module PositionsHelper
  def milestone_level_display(level)
    case level
    when 1
      "Demonstrated"
    when 2
      "Advanced"
    when 3
      "Expert"
    when 4
      "Coach"
    when 5
      "Industry-Recognized"
    else
      "Unknown"
    end
  end

  def current_view_name
    case action_name
    when 'show'
      'Management View'
    when 'job_description'
      'Job Description View'
    when 'manage_assignments'
      'Manage Assignments'
    else
      'Management View'
    end
  end

  def energy_percentage_options(selected_value = nil)
    options = (0..20).map { |i| ["#{i * 5}%", i * 5] }
    # If a selected_value is provided, return pre-selected HTML options
    # Otherwise, return the array for use with form helpers
    selected_value.nil? ? options : options_for_select(options, selected_value)
  end

  def build_assignment_hierarchy_tree(assignments_by_org, company)
    return [] unless company&.company?
    
    result = []
    
    # Get assignments without department (company-level)
    company_assignments = assignments_by_org[nil] || []
    
    # Add company-level assignments if any
    if company_assignments.any?
      result << {
        organization: company,
        assignments: company_assignments,
        level: 0,
        children: []
      }
    end
    
    # Recursively build department structure
    company.children.active.departments.order(:name).each do |department|
      department_assignments = assignments_by_org[department] || []
      
      # Recursively get children departments with assignments
      child_nodes = build_department_children(assignments_by_org, department)
      
      # Only include department if it has assignments or children with assignments
      if department_assignments.any? || child_nodes.any?
        result << {
          organization: department,
          assignments: department_assignments,
          level: department.ancestry_depth,
          children: child_nodes
        }
      end
    end
    
    result
  end

  def department_hierarchy_display(department)
    return department.name unless department&.parent
    
    path = []
    current = department
    while current
      path.unshift(current.name)
      current = current.parent
    end
    path.join(' > ')
  end

  private

  def build_department_children(assignments_by_org, department)
    result = []
    
    department.children.active.departments.order(:name).each do |child_dept|
      child_assignments = assignments_by_org[child_dept] || []
      grandchild_nodes = build_department_children(assignments_by_org, child_dept)
      
      if child_assignments.any? || grandchild_nodes.any?
        result << {
          organization: child_dept,
          assignments: child_assignments,
          level: child_dept.ancestry_depth,
          children: grandchild_nodes
        }
      end
    end
    
    result
  end
end
