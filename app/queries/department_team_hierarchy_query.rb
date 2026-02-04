class DepartmentTeamHierarchyQuery
  def initialize(organization:)
    @organization = organization
  end

  # Returns an array of root department nodes, each with nested children
  # Each node is a hash with: organization (Department), children (array of child nodes), departments_count
  # Uses Department model (Organization no longer has parent/children).
  def call
    return [] unless @organization

    # Root departments for this company
    root_departments = @organization.departments.active.root_departments.includes(:child_departments).order(:name)

    root_departments.map do |dept|
      build_tree_node(dept)
    end
  end

  private

  def build_tree_node(dept)
    children = dept.child_departments.active.includes(:child_departments).order(:name)
    child_nodes = children.map do |child|
      build_tree_node(child)
    end

    departments_count = count_departments(dept)

    {
      organization: dept,
      children: child_nodes,
      departments_count: departments_count
    }
  end

  def count_departments(dept)
    dept.child_departments.active.count +
      dept.child_departments.active.sum { |child| count_departments(child) }
  end
end

