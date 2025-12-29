module ExternalProjectHelper
  def item_term(source)
    case source
    when 'asana'
      'task'
    when 'jira'
      'issue'
    when 'linear'
      'issue'
    else
      'item'
    end
  end

  def section_term(source)
    case source
    when 'asana'
      'section'
    when 'jira'
      'column'
    when 'linear'
      'status'
    else
      'section'
    end
  end

  def source_display_name(source)
    case source
    when 'asana'
      'Asana'
    when 'jira'
      'Jira'
    when 'linear'
      'Linear'
    else
      source&.titleize || 'External Project'
    end
  end

  def has_external_identity?(teammate, source)
    case source
    when 'asana'
      teammate.has_asana_identity?
    when 'jira'
      teammate.has_jira_identity?
    when 'linear'
      teammate.has_linear_identity?
    else
      false
    end
  end

  def external_project_cache_path(cacheable, source, action = :sync)
    case cacheable
    when OneOnOneLink
      case action
      when :sync
        sync_organization_company_teammate_one_on_one_link_path(
          cacheable.teammate.organization,
          cacheable.teammate,
          source: source
        )
      when :associate
        associate_project_organization_company_teammate_one_on_one_link_path(
          cacheable.teammate.organization,
          cacheable.teammate,
          source: source
        )
      when :disassociate
        disassociate_project_organization_company_teammate_one_on_one_link_path(
          cacheable.teammate.organization,
          cacheable.teammate,
          source: source
        )
      end
    else
      # Future: Handle Huddle and Goal
      '#'
    end
  end

  def external_project_item_path(cacheable, item_gid, source)
    case cacheable
    when OneOnOneLink
      organization_company_teammate_one_on_one_link_item_path(
        cacheable.teammate.organization,
        cacheable.teammate,
        item_gid,
        source: source
      )
    else
      # Future: Handle Huddle and Goal
      '#'
    end
  end

  def external_project_oauth_path(cacheable, source)
    case cacheable
    when OneOnOneLink
      case source
      when 'asana'
        asana_oauth_authorize_one_on_one_organization_company_teammate_one_on_one_link_path(
          cacheable.teammate.organization,
          cacheable.teammate,
          return_to: request.fullpath
        )
      else
        '#'
      end
    else
      '#'
    end
  end

  def due_date_status(due_on)
    return nil unless due_on.present?
    due_date = Date.parse(due_on)
    today = Date.current

    if due_date < today
      :overdue
    elsif due_date == today
      :today
    elsif business_days_until(due_date) <= 2
      :soon
    else
      :future
    end
  end

  def business_days_until(date)
    today = Date.current
    return 0 if date <= today

    days = 0
    (today...date).each do |d|
      days += 1 unless d.saturday? || d.sunday?
    end
    days
  end

  def due_date_class(due_on)
    case due_date_status(due_on)
    when :overdue
      'text-danger'
    when :today
      'text-success'
    when :soon
      'text-warning'
    else
      'text-muted'
    end
  end

  def due_date_icon(due_on)
    case due_date_status(due_on)
    when :overdue
      'bi-alarm-fill'
    when :today
      'bi-exclamation-circle-fill'
    when :soon
      'bi-exclamation-triangle-fill'
    else
      'bi-calendar3'
    end
  end
end

