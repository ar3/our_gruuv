class DepartmentTeamHierarchyQuery
  def initialize(organization:)
    @organization = organization
  end

  # Returns an array of root organization nodes, each with nested children
  # Each node is a hash with: organization, children (array of child nodes), departments_count, teams_count
  def call
    return [] unless @organization

    # Get all active child organizations (departments and teams)
    children = @organization.children.active.includes(:children).order(:type, :name)

    # Build tree structure starting from direct children
    children.map do |child|
      build_tree_node(child)
    end
  end

  private

  def build_tree_node(org)
    children = org.children.active.includes(:children).order(:type, :name)
    child_nodes = children.map do |child|
      build_tree_node(child)
    end

    # Calculate counts
    departments_count = count_departments(org)
    teams_count = count_teams(org)

    {
      organization: org,
      children: child_nodes,
      departments_count: departments_count,
      teams_count: teams_count
    }
  end

  def count_departments(org)
    org.children.active.departments.count + 
      org.children.active.sum { |child| count_departments(child) }
  end

  def count_teams(org)
    org.children.active.teams.count + 
      org.children.active.sum { |child| count_teams(child) }
  end
end

