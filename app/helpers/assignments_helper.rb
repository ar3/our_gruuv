module AssignmentsHelper
  def assignments_current_view_name
    return 'Assignment View' unless action_name
    
    # Check if we're in public view
    if request.path.include?('/public_maap/assignments/')
      return 'Public View'
    end
    
    # Check if we're in ability milestones view
    if request.path.include?('/ability_milestones')
      return 'Manage Ability Milestones'
    end
    
    # Check if we're in edit view
    if action_name == 'edit' && controller_name == 'assignments'
      return 'Edit Assignment'
    end
    
    # Check if we're in teammate view
    if @teammate.present? && request.path.include?('/teammates/')
      return 'Teammate View'
    end
    
    # Check if we're in person view
    if @person.present? && !@teammate.present? && request.path.include?('/people/')
      return 'Person View'
    end
    
    # Default to Organization View
    'Organization View'
  end

  def assignment_outcome_management_relationship_label(filter_value)
    return nil unless filter_value.present?
    
    case filter_value
    when 'direct_employee'
      'Actively a direct employee of the Assignment holder'
    when 'direct_manager'
      'Actively the direct manager of the Assignment holder'
    when 'no_relationship'
      'No managerial relationship with assignment holder'
    else
      filter_value.humanize
    end
  end

  def assignment_outcome_team_relationship_label(filter_value)
    return nil unless filter_value.present?
    
    case filter_value
    when 'same_team'
      'On the same team as the Assignment holder'
    when 'different_team'
      'Not on the same team as the Assignment holder'
    else
      filter_value.humanize
    end
  end

  def assignment_outcome_consumer_assignment_label(filter_value, assignment)
    return nil unless filter_value.present?
    
    consumer_assignments = assignment.consumer_assignments.order(:title)
    assignment_list = if consumer_assignments.any?
      consumer_assignments.map(&:title).join(', ')
    else
      'associated assignment that can be defined'
    end
    
    case filter_value
    when 'active_consumer'
      "Teammates who ARE taking on: #{assignment_list}"
    when 'not_consumer'
      "Teammates who ARE NOT taking on: #{assignment_list}"
    else
      filter_value.humanize
    end
  end

  # PaperTrail whodunnit is CompanyTeammate id (legacy: Person id). Used on assignment audit UI.
  def assignment_paper_trail_actor_casual_name(assignment, version)
    return 'Unknown' if version.blank?

    raw = version.whodunnit
    return 'System' if raw.blank?

    teammate = CompanyTeammate.find_by(id: raw.to_s)
    person = teammate&.person || Person.find_by(id: raw.to_s)
    label = person&.casual_name.presence || person&.display_name
    label.presence || 'Unknown'
  end

  def assignment_audit_created_meta(assignment)
    first_version = assignment.versions.order(:created_at).first
    [
      assignment_paper_trail_actor_casual_name(assignment, first_version),
      assignment.created_at
    ]
  end

  def assignment_audit_last_updated_meta(assignment)
    last_update = assignment.versions.where(event: 'update').order(created_at: :desc).first
    if last_update
      [assignment_paper_trail_actor_casual_name(assignment, last_update), last_update.created_at]
    else
      first_version = assignment.versions.order(:created_at).first
      [assignment_paper_trail_actor_casual_name(assignment, first_version), assignment.updated_at]
    end
  end

  def assignment_audit_version_plain_summary(version)
    return 'Assignment created' if version.event == 'create'

    cs = version.changeset.presence || {}
    cs = cs.except('updated_at')
    return 'Updated' if cs.empty?

    parts = cs.map do |attr, (before, after)|
      label = Assignment.human_attribute_name(attr)
      "#{label}: #{format_audit_snapshot(before)} → #{format_audit_snapshot(after)}"
    end
    parts.join('; ')
  end

  def assignment_audit_version_changed_fields_labels(version)
    return '—' if version.event == 'create'

    cs = version.changeset.presence || {}
    cs = cs.except('updated_at')
    return '—' if cs.empty?

    cs.keys.map { |attr| Assignment.human_attribute_name(attr) }.join(', ')
  end

  def assignment_audit_history_popover_html(assignment, versions)
    versions = Array(versions)
    if versions.empty?
      return content_tag(:p, 'No version history recorded.', class: 'mb-0 text-muted')
    end

    rows = versions.map do |v|
      summary_text = truncate(assignment_audit_version_plain_summary(v), length: 180)
      when_text = format_time_in_user_timezone(v.created_at)
      fields_text = assignment_audit_version_changed_fields_labels(v)
      content_tag(:tr) do
        safe_join([
          content_tag(:td, when_text, class: 'text-nowrap'),
          content_tag(:td, assignment_paper_trail_actor_casual_name(assignment, v)),
          content_tag(:td, fields_text),
          content_tag(:td, summary_text)
        ])
      end
    end

    content_tag(:div, class: 'assignment-audit-popover', style: 'max-width: 36rem;') do
      content_tag(:table, class: 'table table-sm table-striped mb-0 align-middle') do
        safe_join([
          content_tag(:thead) do
            content_tag(:tr) do
              safe_join([
                content_tag(:th, 'When'),
                content_tag(:th, 'Who'),
                content_tag(:th, 'Fields'),
                content_tag(:th, 'Change summary')
              ])
            end
          end,
          content_tag(:tbody) { safe_join(rows) }
        ])
      end
    end
  end

  private

  def format_audit_snapshot(value)
    case value
    when nil
      '—'
    when Time, ActiveSupport::TimeWithZone
      format_time_in_user_timezone(value)
    when Date
      format_date_in_user_timezone(value)
    else
      truncate(value.to_s.strip, length: 48)
    end
  end
end
