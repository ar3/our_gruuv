class ObservationVisibilityQuery
  def initialize(person, company)
    @person = person
    @company = company
  end

  def visible_observations
    return Observation.none unless @person.present? && @company.present?

    # Check if person has an active teammate in the company
    has_active_teammate = @person.active_teammates.exists?(organization_id: @company.id)
    
    # If observer doesn't have an active teammate, only return published public_to_world observations
    unless has_active_teammate
      return Observation.where(
        company_id: @company.id,
        deleted_at: nil,
        privacy_level: 'public_to_world'
      ).where.not(published_at: nil)
    end

    # Start with observations in the company
    base_scope = Observation.where(company_id: @company.id, deleted_at: nil)

    # Build visibility conditions for each privacy level
    conditions = []
    params = []

    # observer_only: Only observer can view
    conditions << "(privacy_level = ? AND observer_id = ?)"
    params << 'observer_only'
    params << @person.id

    # observed_only: Observer + all observees
    # Only check active teammates (not terminated)
    if @person.active_teammates.exists?(organization_id: @company.id)
      teammate_ids = @person.active_teammates.where(organization_id: @company.id).pluck(:id)
      conditions << "(privacy_level = ? AND (observer_id = ? OR observations.id IN (SELECT observation_id FROM observees WHERE teammate_id IN (?))))"
      params << 'observed_only'
      params << @person.id
      params << teammate_ids
    else
      conditions << "(privacy_level = ? AND observer_id = ?)"
      params << 'observed_only'
      params << @person.id
    end

    # managers_only: Observer + management hierarchy of all observees
    managed_teammate_ids = managed_teammate_ids_for_person
    if managed_teammate_ids.any?
      conditions << "(privacy_level = ? AND (observer_id = ? OR observations.id IN (SELECT observation_id FROM observees WHERE teammate_id IN (?))))"
      params << 'managers_only'
      params << @person.id
      params << managed_teammate_ids
    else
      conditions << "(privacy_level = ? AND observer_id = ?)"
      params << 'managers_only'
      params << @person.id
    end

    # observed_and_managers: Observer + all observees + management hierarchy + can_manage_employment
    # Only check active teammates (not terminated)
    if @person.active_teammates.exists?(organization_id: @company.id)
      teammate_ids = @person.active_teammates.where(organization_id: @company.id).pluck(:id)
      managed_teammate_ids = managed_teammate_ids_for_person
      
      if managed_teammate_ids.any?
        conditions << "(privacy_level = ? AND (observer_id = ? OR observations.id IN (SELECT observation_id FROM observees WHERE teammate_id IN (?)) OR observations.id IN (SELECT observation_id FROM observees WHERE teammate_id IN (?))))"
        params << 'observed_and_managers'
        params << @person.id
        params << teammate_ids
        params << managed_teammate_ids
      else
        conditions << "(privacy_level = ? AND (observer_id = ? OR observations.id IN (SELECT observation_id FROM observees WHERE teammate_id IN (?))))"
        params << 'observed_and_managers'
        params << @person.id
        params << teammate_ids
      end
    else
      managed_teammate_ids = managed_teammate_ids_for_person
      if managed_teammate_ids.any?
        conditions << "(privacy_level = ? AND (observer_id = ? OR observations.id IN (SELECT observation_id FROM observees WHERE teammate_id IN (?))))"
        params << 'observed_and_managers'
        params << @person.id
        params << managed_teammate_ids
      else
        conditions << "(privacy_level = ? AND observer_id = ?)"
        params << 'observed_and_managers'
        params << @person.id
      end
    end

    # Add can_manage_employment access to all privacy levels EXCEPT observed_only and observer_only
    # For observed_only, we want to respect the "observer + observees only" restriction
    # For observer_only (journal), we want to respect the "observer only" restriction
    teammate = @person.active_teammates.find_by(organization_id: @company.id)
    if teammate&.can_manage_employment?
      conditions << "(company_id = ? AND privacy_level != ? AND privacy_level != ?)"
      params << @company.id
      params << 'observed_only'
      params << 'observer_only'
    end

    # public_to_company: All active authenticated company members can view
    # Only add this condition if person has an active teammate (not terminated)
    if @person.active_teammates.exists?(organization_id: @company.id)
      conditions << "(privacy_level = ? AND company_id = ?)"
      params << 'public_to_company'
      params << @company.id
      
      # public_to_world: Visible to all active authenticated company members
      # (Unauthenticated access via permalinks is handled separately)
      conditions << "(privacy_level = ? AND company_id = ?)"
      params << 'public_to_world'
      params << @company.id
    end

    # Combine all conditions with OR
    where_clause = conditions.join(' OR ')
    
    # Filter results to only include published observations OR drafts where user is observer
    # Draft observations (published_at is nil) should only be visible to their creator, regardless of privacy level
    # BUT: If observer doesn't have active teammate, they can't see drafts even if they're the observer
    result_scope = base_scope.where(where_clause, *params)
    
    # Check if person has an active teammate - if not, only show published public_to_world
    has_active_teammate = @person.active_teammates.exists?(organization_id: @company.id)
    if has_active_teammate
      result_scope = result_scope.where("published_at IS NOT NULL OR observer_id = ?", @person.id)
    else
      # No active teammate: only published public_to_world
      result_scope = result_scope.where("privacy_level = ? AND published_at IS NOT NULL", 'public_to_world')
    end
    
    result_scope
  end

  def visible_to?(observation)
    return false unless @person.present? && @company.present?

    # Check if person has an active teammate in the observation's company
    has_active_teammate = @person.active_teammates.exists?(organization: observation.company)
    
    # If observer doesn't have an active teammate, only allow published public_to_world observations
    unless has_active_teammate
      return observation.published? && observation.privacy_level == 'public_to_world'
    end

    # Draft observations are only visible to their creator (if they have active teammate)
    return false if observation.draft? && observation.observer != @person

    case observation.privacy_level
    when 'observer_only'
      # Journal entries: only observer can see, even with can_manage_employment
      observation.observer == @person
    when 'observed_only'
      observation.observer == @person || user_in_observees?(observation)
    when 'managers_only'
      observation.observer == @person || user_in_management_hierarchy?(observation) || user_can_manage_employment?
    when 'observed_and_managers'
      observation.observer == @person || 
      user_in_observees?(observation) || 
      user_in_management_hierarchy?(observation) || 
      user_can_manage_employment?
    when 'public_to_company'
      # Visible to all authenticated company members
      true
    when 'public_to_world'
      # Visible to everyone (including unauthenticated)
      true
    else
      false
    end
  end

  def can_view_negative_ratings?(observation)
    return false unless visible_to?(observation)
    
    observation.observer == @person || 
    user_in_observees?(observation) || 
    user_in_management_hierarchy?(observation) || 
    user_can_manage_employment?
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
    Teammate.where(organization_id: @company.id, person_id: managed_person_ids, last_terminated_at: nil).pluck(:id)
  end
end