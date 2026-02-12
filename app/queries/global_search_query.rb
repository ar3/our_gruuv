class GlobalSearchQuery
  def initialize(query:, current_organization:, current_teammate:)
    @query = query.to_s.strip
    @current_organization = current_organization
    @current_teammate = current_teammate
    @current_person = current_teammate&.person
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
      titles: [],
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
      titles: [],
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
      when 'Title'
        title = search_result.searchable
        if can_view_title?(title)
          results[:titles] << title
        end
      end
    end

    # Apply organization scoping
    results[:people] = scope_people_to_organization(results[:people])
    results[:organizations] = scope_organizations_to_organization(results[:organizations])
    results[:observations] = scope_observations_to_organization(results[:observations])
    results[:assignments] = scope_assignments_to_organization(results[:assignments])
    results[:abilities] = scope_abilities_to_organization(results[:abilities])
    results[:titles] = scope_titles_to_organization(results[:titles])

    # Calculate total count
    results[:total_count] = results.values.sum(&:size)

    results
  end

  def can_view_person?(person)
    # For search, allow teammates to see each other within the same organization
    # This is more permissive than the standard show? policy
    
    # Users can always see themselves
    return true if @current_person == person
    
    # Users can see others if they're in the same organization
    return true if @current_organization && 
                   person.employment_tenures.where(company: @current_organization).exists? &&
                   @current_person.active_employment_tenure_in?(@current_organization)
    
    # Fall back to standard policy for other cases (admins, etc.)
    return false unless @current_teammate
    pundit_user = OpenStruct.new(user: @current_teammate, real_user: @current_teammate)
    policy = PersonPolicy.new(pundit_user, person)
    policy.show?
  end

  def can_view_organization?(organization)
    return false unless @current_teammate
    pundit_user = OpenStruct.new(user: @current_teammate, real_user: @current_teammate)
    policy = OrganizationPolicy.new(pundit_user, organization)
    policy.show?
  end

  def can_view_observation?(observation)
    return false unless @current_teammate
    pundit_user = OpenStruct.new(user: @current_teammate, real_user: @current_teammate)
    policy = ObservationPolicy.new(pundit_user, observation)
    policy.show?
  end

  def can_view_assignment?(assignment)
    return false unless @current_teammate
    pundit_user = OpenStruct.new(user: @current_teammate, real_user: @current_teammate)
    policy = AssignmentPolicy.new(pundit_user, assignment)
    policy.show?
  end

  def can_view_ability?(ability)
    return false unless @current_teammate
    pundit_user = OpenStruct.new(user: @current_teammate, real_user: @current_teammate)
    policy = AbilityPolicy.new(pundit_user, ability)
    policy.show?
  end

  def can_view_title?(title)
    return false unless @current_teammate
    pundit_user = OpenStruct.new(user: @current_teammate, real_user: @current_teammate)
    policy = TitlePolicy.new(pundit_user, title)
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

    # Get the company for the current organization
    company = @current_organization.company? ? @current_organization : @current_organization.root_company
    
    abilities.select do |ability|
      ability.company_id == company&.id
    end
  end

  def scope_titles_to_organization(titles)
    return [] unless @current_organization

    titles.select do |title|
      title.company == @current_organization ||
        @current_organization.descendants.include?(title.company)
    end
  end
end
