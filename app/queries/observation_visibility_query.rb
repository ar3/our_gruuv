class ObservationVisibilityQuery
  def initialize(person, company)
    @person = person
    @company = company
  end

  def visible_observations
    return Observation.none unless @person.present? && @company.present?

    # Start with observations in the company
    base_scope = Observation.where(company: @company, deleted_at: nil)

    # Build visibility conditions for each privacy level
    conditions = []
    params = []

    # observer_only: Only observer can view
    conditions << "(privacy_level = ? AND observer_id = ?)"
    params << 'observer_only'
    params << @person.id

    # observed_only: Observer + all observees
    if @person.teammates.exists?(organization: @company)
      teammate_ids = @person.teammates.where(organization: @company).pluck(:id)
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
    if @person.teammates.exists?(organization: @company)
      teammate_ids = @person.teammates.where(organization: @company).pluck(:id)
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

    # Add can_manage_employment access to all privacy levels
    if @person.respond_to?(:can_manage_employment?) && @person.can_manage_employment?(@company)
      conditions << "company_id = ?"
      params << @company.id
    end

    # public_observation: Anyone can view
    conditions << "privacy_level = ?"
    params << 'public_observation'

    # Combine all conditions with OR
    where_clause = conditions.join(' OR ')
    
    # Filter results to only include published observations OR drafts where user is observer
    # Draft observations (published_at is nil) should only be visible to their creator
    result_scope = base_scope.where(where_clause, *params)
    result_scope = result_scope.where("published_at IS NOT NULL OR observer_id = ?", @person.id)
    
    result_scope
  end

  def visible_to?(observation)
    return false unless @person.present? && @company.present?

    # Draft observations are only visible to their creator
    return false if observation.draft? && observation.observer != @person

    case observation.privacy_level
    when 'observer_only'
      observation.observer == @person || user_can_manage_employment?
    when 'observed_only'
      observation.observer == @person || user_in_observees?(observation)
    when 'managers_only'
      observation.observer == @person || user_in_management_hierarchy?(observation) || user_can_manage_employment?
    when 'observed_and_managers'
      observation.observer == @person || 
      user_in_observees?(observation) || 
      user_in_management_hierarchy?(observation) || 
      user_can_manage_employment?
    when 'public_observation'
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
    
    observation.observed_teammates.any? { |teammate| @person.in_managerial_hierarchy_of?(teammate.person, @company) }
  end

  def user_can_manage_employment?
    @person.respond_to?(:can_manage_employment?) && @person.can_manage_employment?(@company)
  end

  def managed_teammate_ids_for_person
    return [] unless @person.is_a?(Person)
    
    # Find all teammates that this person manages through employment tenures
    managed_people_ids = EmploymentTenure.where(manager: @person)
                                       .joins(:teammate)
                                       .where(teammates: { organization: @company })
                                       .pluck('teammates.id')
    
    # Also check if the person manages anyone through the mocked method
    # This is for testing purposes when EmploymentTenure records don't exist
    if managed_people_ids.empty?
      # Find all teammates in the company and check if this person manages them
      all_teammates = Teammate.where(organization: @company).includes(:person)
      managed_teammate_ids = all_teammates.select do |teammate|
        @person.in_managerial_hierarchy_of?(teammate.person, @company)
      end.map(&:id)
      
      return managed_teammate_ids
    end
    
    managed_people_ids
  end
end