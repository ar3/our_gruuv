class ActiveEmploymentTenureQuery
  def initialize(person: nil, organization: nil)
    @person = person
    @organization = organization
    raise ArgumentError, "Must provide person, organization, or both" if @person.nil? && @organization.nil?
  end
  
  # Always returns a relation (even if it's one record)
  def all
    scope = EmploymentTenure.active
    
    if @person && @organization
      find_for_person_and_organization(scope)
    elsif @person
      scope.joins(:teammate).where(teammates: { person_id: @person.id })
    elsif @organization
      scope.joins(:teammate).where(teammates: { organization_id: @organization.id })
    end
  end
  
  # Convenience method for person + organization (most common case)
  def first
    all.first
  end
  
  private
  
  def find_for_person_and_organization(scope)
    teammate = @person.teammates.for_organization_hierarchy(@organization).first
    return EmploymentTenure.none unless teammate
    
    scope.where(teammate: teammate)
  end
end




