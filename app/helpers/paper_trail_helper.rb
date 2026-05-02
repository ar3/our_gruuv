module PaperTrailHelper
  # Human-readable actor for a PaperTrail version: prefers +meta+ current/impersonating teammate ids
  # (see ApplicationController#set_paper_trail_controller_info), then falls back to +whodunnit+
  # (CompanyTeammate id or legacy Person id).
  def paper_trail_whodunnit_casual_name(version)
    return 'Unknown' if version.blank?

    imp_id, cur_id = paper_trail_version_teammate_ids_from_meta(version)

    if imp_id.present? && cur_id.present?
      imp_name = casual_name_from_teammate_id(imp_id)
      cur_name = casual_name_from_teammate_id(cur_id)
      if imp_name.present? && cur_name.present?
        return "#{imp_name} impersonating #{cur_name}"
      end
    end

    if cur_id.present? && imp_id.blank?
      name = casual_name_from_teammate_id(cur_id)
      return name if name.present?
    end

    raw = version.whodunnit
    return 'System' if raw.blank?

    teammate = CompanyTeammate.find_by(id: raw.to_s)
    person = teammate&.person || Person.find_by(id: raw.to_s)
    label = person&.casual_name.presence || person&.display_name
    label.presence || 'Unknown'
  end

  # Resolves field-level changes when +Version#changeset+ is empty (YAML safe_load failure,
  # legacy rows, etc.) by re-reading +object_changes+ with +YAML.unsafe_load+ and PaperTrail's
  # attribute deserializer.
  def paper_trail_effective_changeset(version, model_class)
    cs = version.changeset
    if cs.is_a?(Hash) && cs.any?
      cleaned = cs.stringify_keys.except('updated_at')
      return cleaned if cleaned.any?
    end

    raw = version.read_attribute(:object_changes)
    return {} if raw.blank?

    loaded = YAML.unsafe_load(raw)
    return {} unless loaded.is_a?(Hash)

    hwia = ActiveSupport::HashWithIndifferentAccess.new(loaded)
    PaperTrail::AttributeSerializers::ObjectChangesAttribute.new(model_class).deserialize(hwia)
    hwia.stringify_keys.except('updated_at')
  rescue Psych::Exception, Psych::SyntaxError
    {}
  rescue StandardError
    {}
  end

  def paper_trail_version_changed_fields_labels(model_class, version, changeset: nil)
    cs = changeset || paper_trail_effective_changeset(version, model_class)
    return '—' if cs.empty?

    cs.keys.map { |attr| model_class.human_attribute_name(attr) }.join(', ')
  end

  # Field | Before | After table (change history inline panel and legacy popover HTML).
  def paper_trail_version_changes_detail_panel(model_class, version, changeset: nil)
    return ''.html_safe if version.blank?

    cs = changeset || paper_trail_effective_changeset(version, model_class)

    if cs.empty?
      msg =
        if version.event == 'create'
          'No stored attribute changes for this create event (legacy or missing object_changes).'
        else
          'No stored field changes for this version.'
        end
      return content_tag(:p, msg, class: 'small text-muted mb-0')
    end

    thead = content_tag(:thead) do
      content_tag(:tr) do
        safe_join([
          content_tag(:th, 'Field', scope: 'col', class: 'small'),
          content_tag(:th, 'Before', scope: 'col', class: 'small'),
          content_tag(:th, 'After', scope: 'col', class: 'small')
        ])
      end
    end

    tbody = content_tag(:tbody) do
      safe_join(
        cs.map do |attr, (before, after)|
          content_tag(:tr) do
            safe_join([
              content_tag(:td, h(model_class.human_attribute_name(attr)),
                          class: 'small text-nowrap align-top fw-semibold'),
              content_tag(:td, paper_trail_change_cell_content(before),
                          class: 'small align-top paper-trail-change-cell'),
              content_tag(:td, paper_trail_change_cell_content(after),
                          class: 'small align-top paper-trail-change-cell')
            ])
          end
        end
      )
    end

    content_tag(:div, class: 'paper-trail-version-changes-detail text-start') do
      content_tag(:table, safe_join([thead, tbody]),
                  class: 'table table-sm table-bordered mb-0 align-middle')
    end
  end

  # @deprecated Prefer {#paper_trail_version_changes_detail_panel}; kept for callers/tests.
  alias_method :paper_trail_version_changes_popover_content, :paper_trail_version_changes_detail_panel

  def paper_trail_subject_label(record)
    return record.display_name if record.respond_to?(:display_name) && record.display_name.present?
    return record.title if record.respond_to?(:title) && record.title.present?
    return record.name if record.respond_to?(:name) && record.name.present?
    if record.is_a?(AssignmentOutcome) && record.description.present?
      return record.description.to_s.truncate(80)
    end

    "#{record.class.model_name.human} ##{record.id}"
  end

  # Link back to the org-scoped "show" for this record (when a route exists).
  def organization_auditable_show_path(organization, record)
    case record
    when Assignment
      organization_assignment_path(organization, record)
    when Ability
      organization_ability_path(organization, record)
    when Aspiration
      organization_aspiration_path(organization, record)
    when Department
      organization_department_path(organization, record)
    when Goal
      organization_goal_path(organization, record)
    when GoalCheckIn
      organization_goal_path(organization, record.goal)
    when AssignmentOutcome
      organization_assignment_path(organization, record.assignment)
    when Observation
      organization_observation_path(organization, record)
    when Organization
      organization_path(record)
    when Position
      organization_position_path(organization, record)
    when Title
      organization_title_path(organization, record)
    end
  end

  private

  def paper_trail_change_cell_content(value)
    inner =
      case value
      when nil
        content_tag(:span, '—', class: 'text-muted')
      when Time, ActiveSupport::TimeWithZone
        content_tag(:span, format_time_in_user_timezone(value), class: 'font-monospace')
      when Date
        content_tag(:span, format_date_in_user_timezone(value), class: 'font-monospace')
      else
        content_tag(:span, h(value.to_s), class: 'font-monospace')
      end

    content_tag(:div, inner,
                style: 'max-height: 12rem; overflow: auto; white-space: pre-wrap; word-break: break-word;')
  end

  def casual_name_from_teammate_id(teammate_id)
    tid = teammate_id.to_s
    return nil if tid.blank?

    teammate = CompanyTeammate.find_by(id: tid)
    return nil unless teammate&.person

    teammate.person.casual_name.presence || teammate.person.display_name
  end

  def paper_trail_version_teammate_ids_from_meta(version)
    imp_id = nil
    cur_id = nil
    if version.respond_to?(:impersonating_teammate_id)
      imp_id = version.impersonating_teammate_id
    end
    if version.respond_to?(:current_teammate_id)
      cur_id = version.current_teammate_id
    end
    meta = version.respond_to?(:meta) ? version.meta : nil
    if meta.is_a?(Hash)
      imp_id ||= meta['impersonating_teammate_id'] || meta[:impersonating_teammate_id]
      cur_id ||= meta['current_teammate_id'] || meta[:current_teammate_id]
    end
    [imp_id, cur_id]
  end
end
