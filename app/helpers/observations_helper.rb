module ObservationsHelper
  # Returns observations visible to the given person within the organization
  # Uses ObservationVisibilityQuery to respect privacy levels, drafts, and access rules
  def visible_observations_for_person(person, organization)
    return Observation.none unless person.present? && organization.present?
    
    visibility_query = ObservationVisibilityQuery.new(person, organization)
    visibility_query.visible_observations
  end
end

