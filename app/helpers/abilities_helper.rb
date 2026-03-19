module AbilitiesHelper
  # Links to internal teammate page. +version.whodunnit+ is a CompanyTeammate id (legacy: Person id).
  # +fallback_person+ is used when whodunnit is blank (e.g. old imports).
  def ability_spotlight_actor_link(organization, version, fallback_person: nil)
    teammate_from_version, person = ability_spotlight_actor_teammate_and_person(version, fallback_person)
    return content_tag(:em, 'Unknown', class: 'text-muted') unless person

    label = person.casual_name.presence || person.display_name
    link_teammate = teammate_from_version || organization.company_teammates.find_by(person_id: person.id)
    if link_teammate
      link_to label, internal_organization_company_teammate_path(link_teammate.organization, link_teammate), class: 'text-decoration-none'
    else
      label
    end
  end

  def abilities_current_view_name
    return 'View Mode' unless action_name
    
    case action_name
    when 'show'
      'View Mode'
    when 'edit'
      'Edit Mode'
    else
      action_name.titleize
    end
  end

  private

  # Returns [CompanyTeammate or nil, Person or nil]
  def ability_spotlight_actor_teammate_and_person(version, fallback_person)
    return [nil, fallback_person] if version.blank? || version.whodunnit.blank?

    raw = version.whodunnit.to_s
    teammate = CompanyTeammate.find_by(id: raw)
    return [teammate, teammate.person] if teammate

    # Legacy PaperTrail rows stored person id in whodunnit
    person = Person.find_by(id: raw)
    return [nil, person] if person

    [nil, nil]
  end
end
