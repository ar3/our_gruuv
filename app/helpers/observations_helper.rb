module ObservationsHelper
  # Returns observations visible to the given person within the organization
  # Uses ObservationVisibilityQuery to respect privacy levels, drafts, and access rules
  def visible_observations_for_person(person, organization)
    return Observation.none unless person.present? && organization.present?
    
    visibility_query = ObservationVisibilityQuery.new(person, organization)
    visibility_query.visible_observations
  end

  def available_observation_presets_with_permissions(organization, current_company_teammate)
    presets = []
    
    # Kudos preset - available to all
    presets << {
      name: 'Kudos',
      value: 'kudos',
      available: true,
      permission_required: nil,
      tooltip: nil
    }
    
    presets
  end
end

