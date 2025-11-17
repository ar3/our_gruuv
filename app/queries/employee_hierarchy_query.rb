require 'set'

class EmployeeHierarchyQuery
  def initialize(person:, organization:)
    @person = person
    @organization = organization
  end

  # Returns an array of hashes with employee/report information
  # Each hash contains: person_id, name, email, organization_id, organization_name, position, level
  def call
    return [] unless @person && @organization

    direct_reports = []
    visited_reports = Set.new

    collect_reports = lambda do |person, org, visited, reports_list, level = 0|
      # Find all people managed by this person in this organization (including descendants)
      # EmploymentTenure uses 'company' association, not 'organization'
      # For managerial employment, we only care about the teammate record associated with the company
      org_ids = org.company? ? org.self_and_descendants.map(&:id) : [org.id]
      managed_tenures = EmploymentTenure.joins(:teammate)
                                       .where(manager: person)
                                       .where(company_id: org_ids)
                                       .where(teammates: { organization_id: org_ids }) # Ensure teammate is associated with the company
                                       .active
                                       .includes(:teammate, :company, :position)

      managed_tenures.each do |tenure|
        employee = tenure.teammate.person
        next unless employee

        # Only process if we haven't already added this employee
        if !visited.include?(employee.id)
          visited.add(employee.id)
          reports_list << {
            person_id: employee.id,
            name: employee.display_name,
            email: employee.email,
            organization_id: org.id,
            organization_name: org.name,
            position: tenure.position&.display_name,
            level: level
          }

          # Recursively get reports of this employee
          # This will find all people managed by this employee in the same organization
          collect_reports.call(employee, org, visited, reports_list, level + 1)
        end
      end
    end

    # Start collecting from current person
    collect_reports.call(@person, @organization, visited_reports, direct_reports)

    # Sort by level (direct reports first)
    direct_reports.sort_by { |r| r[:level] }
  end
end

