module Organizations::PublicMaapHelper
  # Build organization hierarchy structure for display
  # Returns array of hashes with :organization, :level, and :children keys
  # Only includes Company and Department types, excludes Teams
  def build_organization_hierarchy(company)
    return [] unless company&.company?
    
    build_hierarchy_recursive(company, 0)
  end
  
  # Build full hierarchy path for an organization
  # Returns array of organizations from root company down to the organization
  def department_hierarchy_path(department)
    return [] unless department
    
    path = []
    current = department
    
    # Build path from department up to root
    while current
      path.unshift(current)
      current = current.parent
    end
    
    path
  end
  
  # Format hierarchy path as a string with > separators
  def department_hierarchy_display(department)
    path = department_hierarchy_path(department)
    path.map(&:name).join(' > ')
  end
  
  private
  
  def build_hierarchy_recursive(org, level)
    result = []
    
    # Query children directly from database to ensure we get all children
    # Only include companies and departments, exclude teams
    children = Organization.where(parent_id: org.id)
                          .where(type: ['Company', 'Department'])
                          .order(:name)
    
    children.each do |child|
      child_hash = {
        organization: child,
        level: level,
        children: build_hierarchy_recursive(child, level + 1)
      }
      result << child_hash
    end
    
    result
  end
end

