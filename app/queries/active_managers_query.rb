class ActiveManagersQuery
  def initialize(company:, require_active_teammate: true)
    @company = company
    @require_active_teammate = require_active_teammate
  end

  # Returns CompanyTeammate ActiveRecord relation ordered by person's last_name, first_name
  def call
    # Get organization hierarchy for checking employment tenures
    org_hierarchy = organization_hierarchy

    # Get distinct CompanyTeammate IDs who are managers (have active direct reports)
    manager_teammate_ids = EmploymentTenure.active
                                           .where(company: org_hierarchy)
                                           .where.not(manager_teammate_id: nil)
                                           .distinct
                                           .pluck(:manager_teammate_id)

    # If require_active_teammate is true, filter to only managers who are also active teammates
    if @require_active_teammate
      # Get CompanyTeammate IDs who are active (have active employment tenures themselves)
      active_teammate_ids = EmploymentTenure.active
                                             .joins(:teammate)
                                             .where(company: org_hierarchy, teammates: { organization: org_hierarchy })
                                             .distinct
                                             .pluck('teammates.id')

      # Intersection: managers who are also active teammates
      manager_teammate_ids = manager_teammate_ids & active_teammate_ids
    end

    # Return CompanyTeammate objects ordered by person's last_name, first_name
    CompanyTeammate.where(id: manager_teammate_ids)
                   .joins(:person)
                   .order('people.last_name, people.first_name')
  end

  # Returns array of manager person IDs (useful for set operations)
  def manager_ids
    org_hierarchy = organization_hierarchy

    manager_teammate_ids = EmploymentTenure.active
                                           .where(company: org_hierarchy)
                                           .where.not(manager_teammate_id: nil)
                                           .distinct
                                           .pluck(:manager_teammate_id)

    if @require_active_teammate
      active_teammate_ids = EmploymentTenure.active
                                            .joins(:teammate)
                                            .where(company: org_hierarchy, teammates: { organization: org_hierarchy })
                                            .distinct
                                            .pluck('teammates.id')

      manager_teammate_ids = manager_teammate_ids & active_teammate_ids
    end

    # Return person IDs for backward compatibility with existing code that expects person IDs
    CompanyTeammate.where(id: manager_teammate_ids).pluck(:person_id)
  end

  private

  def organization_hierarchy
    if @company.company?
      @company.self_and_descendants
    else
      [@company, @company.parent].compact
    end
  end
end

