class ObservationVisibilityQuery
  def initialize(person, company)
    @person = person
    @company = company
  end

  def visible_observations
    return Observation.none unless @person.present? && @company.present?

    # Start with observations in the company
    base_scope = Observation.where(company: @company, deleted_at: nil)

    # Build visibility conditions
    conditions = []
    params = []

    # observer_only: Only observer can view
    conditions << "observer_id = ?"
    params << @person.id

    # observed_only: Observer + all observees
    if @person.teammates.exists?(organization: @company)
      teammate_ids = @person.teammates.where(organization: @company).pluck(:id)
      conditions << "id IN (SELECT observation_id FROM observees WHERE teammate_id IN (?))"
      params << teammate_ids
    end

    # managers_only: Observer + management hierarchy of all observees
    managed_teammate_ids = managed_teammate_ids_for_person
    if managed_teammate_ids.any?
      conditions << "id IN (SELECT observation_id FROM observees WHERE teammate_id IN (?))"
      params << managed_teammate_ids
    end

    # observed_and_managers: Observer + all observees + management hierarchy + can_manage_employment
    if @person.respond_to?(:can_manage_employment?) && @person.can_manage_employment?(@company)
      # If user can manage employment, they can see all observations in their company
      conditions << "company_id = ?"
      params << @company.id
    end

    # public_observation: Anyone with the permalink (handled by controller, not query)
    conditions << "privacy_level = ?"
    params << 'public_observation'

    # Combine all conditions with OR
    where_clause = conditions.join(' OR ')
    
    base_scope.where(where_clause, *params)
  end

  def visible_to?(observation)
    return false unless @person.present? && @company.present?

    case observation.privacy_level
    when 'observer_only'
      observation.observer == @person
    when 'observed_only'
      observation.observer == @person || user_in_observees?(observation)
    when 'managers_only'
      observation.observer == @person || user_in_management_hierarchy?(observation)
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
    
    observation.observed_teammates.any? { |teammate| @person.in_managerial_hierarchy_of?(teammate.person) }
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
    
    managed_people_ids
  end
end