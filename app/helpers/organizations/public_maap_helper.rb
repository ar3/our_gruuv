module Organizations::PublicMaapHelper
  # Build organization/department hierarchy for public MAAP views
  # Returns array of hashes with :organization, :level, and :children keys (expected by _organization_hierarchy_item partial)
  def build_organization_hierarchy(company)
    build_department_hierarchy(company).map { |item| department_node_to_organization_node(item) }
  end

  # Build department hierarchy structure for display
  # Returns array of hashes with :department, :level, and :children keys
  def build_department_hierarchy(company)
    return [] unless company&.company?
    
    root_departments = Department.for_company(company).root_departments.active.ordered
    root_departments.map { |dept| build_hierarchy_node(dept, 0) }
  end
  
  # Build full hierarchy path for a department
  # Returns array of departments from root down to the department
  def department_hierarchy_path(department)
    return [] unless department
    return department.self_and_ancestors.reverse if department.is_a?(Department)
    
    # Fallback for Organization (legacy support)
    path = []
    current = department
    
    while current
      path.unshift(current)
      current = current.respond_to?(:parent_department) ? current.parent_department : current.parent
    end
    
    path
  end
  
  # Format hierarchy path as a string with > separators
  def department_hierarchy_display(department)
    return '' unless department
    return department.display_name if department.is_a?(Department)
    
    path = department_hierarchy_path(department)
    path.map(&:name).join(' > ')
  end
  
  private

  def department_node_to_organization_node(item)
    {
      organization: item[:department],
      level: item[:level],
      children: (item[:children] || []).map { |c| department_node_to_organization_node(c) }
    }
  end

  def build_hierarchy_node(department, level)
    {
      department: department,
      level: level,
      children: department.child_departments.active.ordered.map { |child| build_hierarchy_node(child, level + 1) }
    }
  end
end
