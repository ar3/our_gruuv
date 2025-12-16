class ActiveManagersQuery
  def initialize(company:, require_active_teammate: true)
    @company = company
    @require_active_teammate = require_active_teammate
  end

  # Returns Person ActiveRecord relation ordered by last_name, first_name
  def call
    # Get organization hierarchy for checking employment tenures
    org_hierarchy = organization_hierarchy

    # Get distinct Person IDs who are managers (have active direct reports)
    manager_ids = EmploymentTenure.active
                                  .where(company: org_hierarchy)
                                  .where.not(manager_id: nil)
                                  .distinct
                                  .pluck(:manager_id)

    # If require_active_teammate is true, filter to only managers who are also active teammates
    if @require_active_teammate
      # Get people who are active company teammates (have active employment tenures themselves)
      active_teammate_person_ids = EmploymentTenure.active
                                                    .joins(:teammate)
                                                    .where(company: org_hierarchy, teammates: { organization: org_hierarchy })
                                                    .distinct
                                                    .pluck('teammates.person_id')

      # Intersection: managers who are also active teammates
      manager_ids = manager_ids & active_teammate_person_ids
    end

    # Return Person objects ordered by last_name, first_name
    Person.where(id: manager_ids)
          .order(:last_name, :first_name)
  end

  # Returns array of manager person IDs (useful for set operations)
  def manager_ids
    org_hierarchy = organization_hierarchy

    manager_ids = EmploymentTenure.active
                                  .where(company: org_hierarchy)
                                  .where.not(manager_id: nil)
                                  .distinct
                                  .pluck(:manager_id)

    if @require_active_teammate
      active_teammate_person_ids = EmploymentTenure.active
                                                    .joins(:teammate)
                                                    .where(company: org_hierarchy, teammates: { organization: org_hierarchy })
                                                    .distinct
                                                    .pluck('teammates.person_id')

      manager_ids = manager_ids & active_teammate_person_ids
    end

    manager_ids
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

