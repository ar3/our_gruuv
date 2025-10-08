class GlobalSearchQuery
  def initialize(query:, current_organization:, current_person:)
    @query = query.to_s.strip
    @current_organization = current_organization
    @current_person = current_person
  end

  def call
    return empty_results if @query.blank?

    search_results = PgSearch.multisearch(@query)
    filter_by_authorization(search_results)
  end

  private

  def empty_results
    {
      people: [],
      organizations: [],
      observations: [],
      assignments: [],
      abilities: [],
      total_count: 0
    }
  end

  def filter_by_authorization(search_results)
    results = {
      people: [],
      organizations: [],
      observations: [],
      assignments: [],
      abilities: [],
      total_count: 0
    }

    search_results.each do |search_result|
      case search_result.searchable_type
      when 'Person'
        person = search_result.searchable
        if can_view_person?(person)
          results[:people] << person
        end
      when 'Organization'
        organization = search_result.searchable
        if can_view_organization?(organization)
          results[:organizations] << organization
        end
      when 'Observation'
        observation = search_result.searchable
        if can_view_observation?(observation)
          results[:observations] << observation
        end
      when 'Assignment'
        assignment = search_result.searchable
        if can_view_assignment?(assignment)
          results[:assignments] << assignment
        end
      when 'Ability'
        ability = search_result.searchable
        if can_view_ability?(ability)
          results[:abilities] << ability
        end
      end
    end

    # Apply organization scoping
    results[:people] = scope_people_to_organization(results[:people])
    results[:organizations] = scope_organizations_to_organization(results[:organizations])
    results[:observations] = scope_observations_to_organization(results[:observations])
    results[:assignments] = scope_assignments_to_organization(results[:assignments])
    results[:abilities] = scope_abilities_to_organization(results[:abilities])

    # Calculate total count
    results[:total_count] = results.values.sum(&:size)

    results
  end

  def can_view_person?(person)
    policy = PersonPolicy.new(@current_person, person)
    policy.show?
  end

  def can_view_organization?(organization)
    policy = OrganizationPolicy.new(@current_person, organization)
    policy.show?
  end

  def can_view_observation?(observation)
    policy = ObservationPolicy.new(@current_person, observation)
    policy.show?
  end

  def can_view_assignment?(assignment)
    policy = AssignmentPolicy.new(@current_person, assignment)
    policy.show?
  end

  def can_view_ability?(ability)
    policy = AbilityPolicy.new(@current_person, ability)
    policy.show?
  end

  def scope_people_to_organization(people)
    return [] unless @current_organization

    people.select do |person|
      person.teammates.exists?(organization: @current_organization)
    end
  end

  def scope_organizations_to_organization(organizations)
    return [] unless @current_organization

    organizations.select do |organization|
      organization == @current_organization || 
      organization.descendants.include?(@current_organization) ||
      @current_organization.descendants.include?(organization)
    end
  end

  def scope_observations_to_organization(observations)
    return [] unless @current_organization

    observations.select do |observation|
      observation.company == @current_organization ||
      @current_organization.descendants.include?(observation.company)
    end
  end

  def scope_assignments_to_organization(assignments)
    return [] unless @current_organization

    assignments.select do |assignment|
      assignment.company == @current_organization ||
      @current_organization.descendants.include?(assignment.company)
    end
  end

  def scope_abilities_to_organization(abilities)
    return [] unless @current_organization

    abilities.select do |ability|
      ability.organization == @current_organization ||
      @current_organization.descendants.include?(ability.organization)
    end
  end
end
