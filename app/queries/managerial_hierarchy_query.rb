require 'set'

class ManagerialHierarchyQuery
  def initialize(person:, organization:)
    @person = person
    @organization = organization
  end

  # Returns an array of hashes with manager information
  # Each hash contains: person_id, name, email, organization_id, organization_name, tenure, level
  def call
    return [] unless @person && @organization

    managers = []
    visited_managers = Set.new

    collect_managers = lambda do |person, org, visited, managers_list, level = 0|
      # Get active employment tenures for this person in this organization
      tenures = EmploymentTenure.joins(:teammate)
                               .where(teammates: { person: person, organization: org })
                               .active
                               .includes(:manager, :company, :position)

      tenures.each do |tenure|
        manager = tenure.manager
        next unless manager

        # Only process if we haven't already added this manager
        if !visited.include?(manager.id)
          visited.add(manager.id)
          manager_tenure = EmploymentTenure.joins(:teammate)
                                          .where(teammates: { person: manager, organization: org })
                                          .active
                                          .includes(:position)
                                          .first

          managers_list << {
            person_id: manager.id,
            name: manager.display_name,
            email: manager.email,
            organization_id: org.id,
            organization_name: org.name,
            tenure: manager_tenure&.position&.display_name,
            level: level
          }

          # Recursively get managers of this manager
          collect_managers.call(manager, org, visited, managers_list, level + 1)
        end
      end
    end

    # Start collecting from current person
    collect_managers.call(@person, @organization, visited_managers, managers)

    # Sort by level (closest managers first)
    managers.sort_by { |m| m[:level] }
  end
end

