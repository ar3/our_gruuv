class OrganizationHierarchyQuery
  def initialize(organization:)
    @organization = organization
  end

  # Returns a hash with :nodes and :links arrays for Highcharts organization chart
  # Nodes: [{ id, title, name }]
  # Links: [{ from, to }]
  def call
    return { nodes: [], links: [] } unless @organization

    # Get all active employment tenures for this organization
    # For companies, include descendants; for teams/departments, just the organization
    org_ids = @organization.company? ? @organization.self_and_descendants.map(&:id) : [@organization.id]
    
    tenures = EmploymentTenure.joins(:teammate)
                             .joins('INNER JOIN people ON teammates.person_id = people.id')
                             .where(company_id: org_ids)
                            .where(teammates: { organization_id: org_ids })
                            .active
                            .includes(:teammate, manager_teammate: :person, position: nil)
                            .order('employment_tenures.manager_teammate_id NULLS FIRST, people.last_name, people.first_name')

    # Build nodes hash keyed by person_id for easy lookup
    nodes_hash = {}
    links = []

    tenures.each do |tenure|
      person = tenure.teammate.person
      next unless person

      person_id = "person_#{person.id}"

      # Add node if not already added
      unless nodes_hash[person_id]
        nodes_hash[person_id] = {
          id: person_id,
          title: tenure.position&.display_name || 'No Position',
          name: person.display_name
        }
      end

      # Add link if there's a manager
      if tenure.manager_teammate
        manager_person = tenure.manager_teammate.person
        manager_id = "person_#{manager_person.id}"
        links << {
          from: manager_id,
          to: person_id
        }

        # Ensure manager node exists (in case manager's tenure isn't in this org)
        unless nodes_hash[manager_id]
          manager_tenure = EmploymentTenure.joins(:teammate)
                                          .where(teammates: { person: manager_person, organization_id: org_ids })
                                          .active
                                          .includes(:position)
                                          .first

          nodes_hash[manager_id] = {
            id: manager_id,
            title: manager_tenure&.position&.display_name || 'No Position',
            name: manager_person.display_name
          }
        end
      end
    end

    # Convert nodes hash to array
    nodes = nodes_hash.values

    # Remove duplicate links
    links.uniq!

    { nodes: nodes, links: links }
  end
end

