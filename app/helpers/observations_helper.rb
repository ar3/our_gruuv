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

  def observation_visibility_reason(observation, current_person, organization)
    return "Cannot view: No current person" unless current_person.present?
    
    person = current_person
    company = observation.company
    
    # Check if person has an active teammate in the observation's company
    has_active_teammate = person.active_teammates.exists?(organization: company)
    
    # If observer doesn't have an active teammate, only allow published public_to_world observations
    unless has_active_teammate
      if observation.published? && observation.privacy_level == 'public_to_world'
        return "You can view this because it's published and public_to_world (you don't have an active teammate in this company)"
      else
        return "Cannot view: You don't have an active teammate in this company (only public_to_world published observations are visible)"
      end
    end
    
    # Draft observations: only the observer can see them
    if observation.draft?
      if person == observation.observer
        return "You can view this because you are the observer and it's a draft"
      else
        return "Cannot view: This is a draft and you are not the observer"
      end
    end
    
    # Observer is always allowed for published observations
    if person == observation.observer
      return "You can view this because you are the observer"
    end
    
    # Check privacy level
    case observation.privacy_level
    when 'observer_only'
      "Cannot view: This is observer_only (journal) and you are not the observer"
    when 'observed_only'
      visibility_query = ObservationVisibilityQuery.new(person, company)
      if visibility_query.send(:user_in_observees?, observation)
        "You can view this because you are one of the observed people (observed_only)"
      else
        "Cannot view: This is observed_only and you are not the observer or one of the observed"
      end
    when 'managers_only'
      visibility_query = ObservationVisibilityQuery.new(person, company)
      if visibility_query.send(:user_in_management_hierarchy?, observation)
        "You can view this because you are in the management hierarchy of one of the observed (managers_only)"
      elsif visibility_query.send(:user_can_manage_employment?)
        "You can view this because you have can_manage_employment permission (managers_only)"
      else
        "Cannot view: This is managers_only and you are not the observer, a manager, or have can_manage_employment"
      end
    when 'observed_and_managers'
      visibility_query = ObservationVisibilityQuery.new(person, company)
      reasons = []
      if visibility_query.send(:user_in_observees?, observation)
        reasons << "you are one of the observed"
      end
      if visibility_query.send(:user_in_management_hierarchy?, observation)
        reasons << "you are in the management hierarchy"
      end
      if visibility_query.send(:user_can_manage_employment?)
        reasons << "you have can_manage_employment permission"
      end
      if reasons.any?
        "You can view this because #{reasons.join(' and ')} (observed_and_managers)"
      else
        "Cannot view: This is observed_and_managers and you are not the observer, observed, manager, or have can_manage_employment"
      end
    when 'public_to_company'
      "You can view this because it's public_to_company and you have an active teammate in this company"
    when 'public_to_world'
      "You can view this because it's public_to_world (visible to everyone)"
    else
      "Cannot view: Unknown privacy level"
    end
  end

  def observation_type_icon(observation_type)
    case observation_type.to_s
    when 'kudos'
      'bi-trophy'
    when 'feedback'
      'bi-chat-left-text'
    when 'quick_note'
      'bi-sticky'
    else # 'generic'
      'bi-eye'
    end
  end

  def observation_type_name(observation_type)
    case observation_type.to_s
    when 'kudos'
      'Kudos'
    when 'feedback'
      'Feedback'
    when 'quick_note'
      'Quick Note'
    else # 'generic'
      'Observation'
    end
  end

  def privacy_level_display_text(observation)
    observee_names = observation.observed_teammates.map { |t| t.person.casual_name }
    
    # Get manager names for all observees (deduplicated)
    manager_names = []
    observation.observed_teammates.each do |teammate|
      managers = ManagerialHierarchyQuery.new(person: teammate.person, organization: observation.company).call
      managers.each do |manager_info|
        manager_name = manager_info[:name]
        manager_names << manager_name unless manager_names.include?(manager_name)
      end
    end
    
    case observation.privacy_level
    when 'observer_only'
      '🔒 Just for me (Journal)'
    when 'observed_only'
      if observee_names.any?
        "👤 Just Observees: #{observee_names.join(', ')}"
      else
        '👤 Just for their eyes only'
      end
    when 'managers_only'
      if manager_names.any?
        "👔 Just Managers: #{manager_names.join(', ')}"
      else
        '👔 Just for their manager\'s eyes only'
      end
    when 'observed_and_managers'
      observee_text = observee_names.any? ? "Observees: #{observee_names.join(', ')}" : 'Observees'
      manager_text = manager_names.any? ? "Managers: #{manager_names.join(', ')}" : 'Managers'
      "👥 #{observee_text} AND #{manager_text}"
    when 'public_to_company'
      "🏢 Public to #{observation.company.name}"
    when 'public_to_world'
      '🌍 Public to world'
    else
      observation.privacy_level.humanize
    end
  end

  def observation_date_text(observation)
    created_date = observation.created_at.to_date
    published_date = observation.published_at&.to_date
    
    if observation.draft?
      "draft created on #{observation.created_at.strftime('%m/%d/%y')}"
    elsif published_date && created_date == published_date
      "published on #{observation.published_at.strftime('%m/%d/%y')}"
    elsif published_date
      "created on #{observation.created_at.strftime('%m/%d/%y')} and published on #{observation.published_at.strftime('%m/%d/%y')}"
    else
      "created on #{observation.created_at.strftime('%m/%d/%y')}"
    end
  end

  def other_managers_popover_content(other_manager_names)
    return '' if other_manager_names.empty?
    
    list_items = other_manager_names.map { |name| "<li>#{ERB::Util.html_escape(name)}</li>" }.join
    "The following may not be notified, but they'll be able to view this:<ul class='mb-0 mt-1'>#{list_items}</ul>".html_safe
  end
end

