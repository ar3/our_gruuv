require 'set'

class VerticalHierarchyQuery
  def initialize(organization:)
    @organization = organization
  end

  # Returns an array of root employee nodes, each with nested children
  # Each node is a hash with: person, position, children (array of child nodes), direct_reports_count, total_reports_count
  def call
    return [] unless @organization

    # Get all active employment tenures for this organization
    # For companies, include descendants; for teams/departments, just the organization
    org_ids = @organization.company? ? @organization.self_and_descendants.map(&:id) : [@organization.id]
    
    tenures = EmploymentTenure.joins(:teammate)
                             .joins('INNER JOIN people ON teammates.person_id = people.id')
                             .where(company_id: org_ids)
                             .where(teammates: { organization_id: org_ids })
                             .active
                             .includes(:teammate, :manager_teammate, :position, :seat)
                             .order('people.last_name, people.first_name')

    # Build person data hash and parent-child map
    person_data = {}
    parent_child_map = {}
    people_with_managers = Set.new

    tenures.each do |tenure|
      person = tenure.teammate.person
      next unless person

      person_id = person.id

      # Store person data if not already stored
      unless person_data[person_id]
        person_data[person_id] = {
          person: person,
          position: tenure.position&.display_name || 'No Position',
          employment_tenure: tenure
        }
      end

      # Build parent-child relationships
      if tenure.manager_teammate
        manager_person = tenure.manager_teammate.person
        manager_id = manager_person.id
        parent_child_map[manager_id] ||= []
        parent_child_map[manager_id] << person_id
        people_with_managers.add(person_id)

        # Ensure manager data exists (in case manager's tenure isn't in this org)
        unless person_data[manager_id]
          manager_tenure = EmploymentTenure.joins(:teammate)
                                          .where(teammates: { person: manager_person, organization_id: org_ids })
                                          .active
                                          .includes(:position, :seat)
                                          .first

          person_data[manager_id] = {
            person: manager_person,
            position: manager_tenure&.position&.display_name || 'No Position',
            employment_tenure: manager_tenure
          }
        end
      end
    end

    # Find root employees (those with no manager)
    all_person_ids = person_data.keys.to_set
    root_person_ids = all_person_ids - people_with_managers

    # Build tree structure starting from roots
    root_person_ids.map do |person_id|
      build_tree_node(person_id, person_data, parent_child_map)
    end.sort_by { |node| node[:person].display_name }
  end

  private

  def build_tree_node(person_id, person_data, parent_child_map)
    data = person_data[person_id]
    return nil unless data

    children_ids = parent_child_map[person_id] || []
    children = children_ids.map do |child_id|
      build_tree_node(child_id, person_data, parent_child_map)
    end.compact.sort_by { |node| node[:person].display_name }

    # Calculate direct reports (immediate children) and total reports (all descendants)
    direct_reports_count = children.length
    total_reports_count = direct_reports_count + children.sum { |child| child[:total_reports_count] }

    {
      person: data[:person],
      position: data[:position],
      employment_tenure: data[:employment_tenure],
      children: children,
      direct_reports_count: direct_reports_count,
      total_reports_count: total_reports_count
    }
  end
end

