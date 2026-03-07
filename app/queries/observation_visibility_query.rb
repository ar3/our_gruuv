class ObservationVisibilityQuery
  def initialize(person, company)
    @person = person
    @company = company
  end

  def visible_observations
    return Observation.none unless @person.present? && @company.present?

    # Get current teammate (must be active)
    current_teammate = @person.active_teammates.find_by(organization_id: @company.id)
    
    # If no active teammate, only return published public_to_world observations (not soft-deleted)
    unless current_teammate
      return Observation.where(
        company_id: @company.id,
        deleted_at: nil,
        privacy_level: 'public_to_world'
      ).where.not(published_at: nil)
    end

    # Start with observations in the company
    # We'll exclude soft-deleted in the base_scope, but include observer's soft-deleted via OR
    base_scope = Observation.where(company_id: @company.id, deleted_at: nil)

    # Build visibility conditions according to the 4 rules
    conditions = []
    params = []

    # Rule 1: Public observations (published, not soft-deleted)
    # privacy_level IN ('public_to_company', 'public_to_world') AND published_at IS NOT NULL
    conditions << "(privacy_level IN (?, ?) AND published_at IS NOT NULL)"
    params << 'public_to_company'
    params << 'public_to_world'

    # Rule 2: Current teammate is the observer (regardless of published state, privacy level, or soft-deleted status)
    # observer_id = current_teammate.person_id
    # Note: This will match both non-soft-deleted (via base_scope) and soft-deleted (via OR below)
    conditions << "(observer_id = ?)"
    params << @person.id

    # Rule 3: Current teammate is one of the observed (published)
    # current_teammate.id IN (SELECT teammate_id FROM observees WHERE observation_id = observations.id)
    # AND published_at IS NOT NULL
    # AND privacy_level IN ('observed_only', 'observed_and_managers')
    conditions << "(observations.id IN (SELECT observation_id FROM observees WHERE teammate_id = ?) AND published_at IS NOT NULL AND privacy_level IN (?, ?))"
    params << current_teammate.id
    params << 'observed_only'
    params << 'observed_and_managers'

    # Rule 4: Current teammate is in the managerial hierarchy of observed (published)
    # Current teammate is a manager (direct or indirect) of ANY observee.
    # Use a downward recursive CTE from current_teammate to get all report teammate_ids,
    # then include observations that have an observee in that set.
    manager_condition = <<-SQL.squish
      observations.id IN (
        SELECT observees.observation_id
        FROM observees
        INNER JOIN (
          WITH RECURSIVE manager_reports(teammate_id, depth) AS (
            SELECT CAST(? AS bigint) AS teammate_id, 0 AS depth
            UNION ALL
            SELECT et.teammate_id, mr.depth + 1
            FROM manager_reports mr
            INNER JOIN employment_tenures et ON et.manager_teammate_id = mr.teammate_id AND et.company_id = CAST(? AS bigint) AND et.ended_at IS NULL
            WHERE mr.depth < 20
          )
          SELECT teammate_id FROM manager_reports WHERE depth > 0
        ) reports ON reports.teammate_id = observees.teammate_id
      )
      AND published_at IS NOT NULL
      AND privacy_level IN (?, ?)
    SQL
    conditions << manager_condition
    params << current_teammate.id
    params << @company.id
    params << 'observed_and_managers'
    params << 'managers_only'

    # Combine all conditions with OR
    where_clause = conditions.join(' OR ')
    
    # Apply the combined conditions to non-soft-deleted observations
    visible_scope = base_scope.where(where_clause, *params)
    
    # For observer, explicitly include their soft-deleted observations
    # This allows observer to see their own archived observations
    observer_soft_deleted = Observation.where(company_id: @company.id, observer_id: @person.id).where.not(deleted_at: nil)
    visible_scope = visible_scope.or(observer_soft_deleted)
    
    visible_scope
  end

  def visible_to?(observation)
    return false unless @person.present? && @company.present?

    # Get current teammate (must be active)
    current_teammate = @person.active_teammates.find_by(organization_id: @company.id)
    
    # If no active teammate, only allow published public_to_world observations (not soft-deleted)
    unless current_teammate
      return observation.published? && observation.privacy_level == 'public_to_world' && !observation.soft_deleted?
    end

    # Soft-deleted observations: only visible to observer
    return false if observation.soft_deleted? && observation.observer_id != @person.id

    # Rule 1: Public observations (published, not soft-deleted)
    if observation.published? && ['public_to_company', 'public_to_world'].include?(observation.privacy_level) && !observation.soft_deleted?
      return true
    end

    # Rule 2: Current teammate is the observer (regardless of published state, privacy level, or soft-deleted status)
    if observation.observer_id == @person.id
      return true
    end

    # Rules 3 and 4 require published observations (and not soft-deleted)
    return false unless observation.published? && !observation.soft_deleted?

    # Rule 3: Current teammate is one of the observed
    if ['observed_only', 'observed_and_managers'].include?(observation.privacy_level)
      if observation.observed_teammates.any? { |teammate| teammate.id == current_teammate.id }
        return true
      end
    end

    # Rule 4: Current teammate is in the managerial hierarchy of any observee
    if ['observed_and_managers', 'managers_only'].include?(observation.privacy_level)
      return true if observation.observed_teammates.any? { |observee_tm| current_teammate.in_managerial_hierarchy_of?(observee_tm) }
    end

    false
  end

  def can_view_negative_ratings?(observation)
    return false unless visible_to?(observation)
    
    # Get current teammate
    current_teammate = @person.active_teammates.find_by(organization_id: @company.id)
    return false unless current_teammate

    # Observer can always see negative ratings
    return true if observation.observer_id == @person.id

    # Observees can see negative ratings
    if observation.observed_teammates.any? { |teammate| teammate.id == current_teammate.id }
      return true
    end

    # Managers (in hierarchy) can see negative ratings
    return true if observation.observed_teammates.any? { |observee_tm| current_teammate.in_managerial_hierarchy_of?(observee_tm) }

    false
  end

  private

  def user_in_observees?(observation)
    return false unless @person.is_a?(Person)
    
    observation.observed_teammates.any? { |teammate| teammate.person == @person }
  end

  def user_in_management_hierarchy?(observation)
    return false unless @person.is_a?(Person)
    
    viewing_teammate = CompanyTeammate.find_by(organization_id: @company.id, person: @person)
    return false unless viewing_teammate
    
    observation.observed_teammates.any? do |observed_teammate|
      observed_company_teammate = observed_teammate.is_a?(CompanyTeammate) ? observed_teammate : CompanyTeammate.find_by(organization_id: @company.id, person: observed_teammate.person)
      observed_company_teammate && viewing_teammate.in_managerial_hierarchy_of?(observed_company_teammate)
    end
  end

  def user_can_manage_employment?
    # Only check active teammates (not terminated)
    teammate = @person.active_teammates.find_by(organization_id: @company.id)
    teammate&.can_manage_employment? || false
  end

  def managed_teammate_ids_for_person
    return [] unless @person.is_a?(Person)
    
    # Use EmployeeHierarchyQuery to find all reports (direct and indirect) in the hierarchy
    reports = EmployeeHierarchyQuery.new(person: @person, organization: @company).call
    
    # Extract person IDs from the returned hashes
    managed_person_ids = reports.map { |r| r[:person_id] }
    
    # Find active teammates for those person IDs in the organization (not terminated)
    CompanyTeammate.where(organization_id: @company.id, person_id: managed_person_ids, last_terminated_at: nil).pluck(:id)
  end
end
