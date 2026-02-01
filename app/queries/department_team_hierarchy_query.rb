class DepartmentTeamHierarchyQuery
  def initialize(organization:)
    @organization = organization
  end

  # Returns an array of root organization nodes, each with nested children
  # Each node is a hash with: organization, children (array of child nodes), departments_count
  # NOTE: STI Team has been removed. Use the standalone Team model for teams.
  def call
    return [] unless @organization

    # Get all active child organizations (departments only - STI Team removed)
    children = @organization.children.active.departments.includes(:children).order(:name)

    # Build tree structure starting from direct children
    children.map do |child|
      build_tree_node(child)
    end
  end

  private

  def build_tree_node(org)
    children = org.children.active.departments.includes(:children).order(:name)
    child_nodes = children.map do |child|
      build_tree_node(child)
    end

    # Calculate counts
    departments_count = count_departments(org)

    {
      organization: org,
      children: child_nodes,
      departments_count: departments_count
    }
  end

  def count_departments(org)
    org.children.active.departments.count + 
      org.children.active.sum { |child| count_departments(child) }
  end
end

