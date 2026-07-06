# frozen_string_literal: true

module CheckInsHealthBarsHelper
  EH_STATUS_CSS = {
    EngagementHealth::HEALTHY => "check-in-health-eh-healthy",
    EngagementHealth::AT_RISK => "check-in-health-eh-at-risk",
    EngagementHealth::NEEDS_ATTENTION => "check-in-health-eh-needs-attention"
  }.freeze

  ACTION_BAR_CSS = {
    "light_green" => "check-in-health-action-light-green",
    "light_blue" => "check-in-health-action-light-blue",
    "light_purple" => "check-in-health-action-light-purple",
    "orange" => "check-in-health-action-orange",
    "red" => "check-in-health-action-red",
    "green_striped" => "check-in-health-action-green-striped",
    "neon_green_striped" => "check-in-health-action-neon-green-striped",
    "anomaly_gray" => "check-in-health-action-anomaly-gray"
  }.freeze

  ACTION_BAR_LABELS = {
    "light_green" => "Both sides completed — ready to finalize",
    "light_blue" => "Employee completed; awaiting manager check-in",
    "light_purple" => "Manager completed; awaiting employee check-in",
    "orange" => "Check-in overdue — start the process",
    "red" => "Needs attention — no progress on open check-in",
    "green_striped" => "Healthy — previous check-in awaiting acknowledgment",
    "neon_green_striped" => "Healthy — previous check-in finalized and acknowledged",
    "anomaly_gray" => "Unexpected state — refresh Gruuv Health"
  }.freeze

  def check_ins_health_eh_status_swatch_css(status)
    EH_STATUS_CSS.fetch(status, "check-in-health-action-anomaly-gray")
  end

  def check_ins_health_item_initials(name)
    words = name.to_s.strip.split(/\s+/).reject(&:blank?)
    return "?" if words.empty?

    if words.size >= 2
      words.first(2).map { |word| word.gsub(/[^A-Za-z0-9]/, "").first }.compact.join.upcase.presence || "?"
    else
      words.first.to_s.gsub(/[^A-Za-z0-9]/, "").first(2).upcase.presence || "?"
    end
  end

  def check_ins_health_item_bar_segments(records:, entity_type:, teammate:, organization:)
    items = check_ins_health_engagement_items(records, entity_type: entity_type)
    return [] if items.empty?

    names = teammate_and_manager_short_names(teammate, organization)
    flex_percent = (100.0 / items.size).round(4)

    items.sort_by { |item| item.inputs["name"].to_s.downcase }.map do |item|
      inputs = item.inputs
      action_color = check_ins_health_resolved_action_bar_color(item)
      segment = {
        name: inputs["name"].to_s,
        entity_type: item.entity_type,
        entity_id: item.entity_id,
        eh_status: item.status,
        eh_css: EH_STATUS_CSS.fetch(item.status, "check-in-health-action-anomaly-gray"),
        action_color: action_color,
        action_css: ACTION_BAR_CSS.fetch(action_color, "check-in-health-action-anomaly-gray"),
        flex_percent: flex_percent,
        url: check_ins_health_bar_segment_url(
          organization: organization,
          teammate: teammate,
          entity_type: item.entity_type,
          entity_id: item.entity_id
        ),
        popover_html: check_ins_health_bar_popover_html(
          item: item,
          employee_name: names[:employee],
          manager_name: names[:manager]
        )
      }
      if item.entity_type.in?(%w[Aspiration Assignment])
        segment[:initials] = check_ins_health_item_initials(segment[:name])
      end
      segment
    end
  end

  def check_ins_health_bar_popover_html(item:, employee_name:, manager_name:)
    name = ERB::Util.html_escape(item.inputs["name"].to_s)
    status_label = ERB::Util.html_escape(EngagementHealth::STATUS_LABELS.fetch(item.status))
    last_finalized = format_check_ins_health_last_finalized(item.inputs["last_event_at"])
    action_label = ERB::Util.html_escape(
      ACTION_BAR_LABELS.fetch(check_ins_health_resolved_action_bar_color(item), "Unexpected state — refresh Gruuv Health")
    )

    body = if show_workflow_steps_popover?(item)
             workflow_steps_popover_body(
               item: item,
               employee_name: employee_name,
               manager_name: manager_name
             )
           else
             healthy_popover_body(item: item)
           end

    <<~HTML.squish
      <div class="small text-start check-ins-health-bar-popover">
        <strong>#{name}</strong><br>
        Gruuv Health: #{status_label}<br>
        Last finalized: #{last_finalized}<br>
        <span class="text-muted">#{action_label}</span>
        #{body}
      </div>
    HTML
  end

  def check_ins_health_resolved_action_bar_color(item)
    color = item.inputs["action_bar_color"].to_s.presence
    return color if color.present? && ACTION_BAR_CSS.key?(color)

    check_ins_health_inferred_action_bar_color(item)
  end

  def check_ins_health_resolved_days_until_at_risk(item)
    days = item.inputs["days_until_at_risk"]
    return days unless days.nil?
    return 0 unless item.status == EngagementHealth::HEALTHY

    days_since = check_ins_health_resolved_days_since_last_event(item)
    return nil if days_since.nil?

    remaining = EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS + 1 - days_since.to_i
    remaining.positive? ? remaining : 0
  end

  def check_ins_health_action_bar_legend_items
    ACTION_BAR_LABELS.map do |color, label|
      { color: color, css: ACTION_BAR_CSS.fetch(color), label: label }
    end
  end

  def check_ins_health_bar_segment_url(organization:, teammate:, entity_type:, entity_id:)
    case entity_type.to_s
    when "Position"
      position_check_in_organization_teammate_path(organization, teammate)
    when "Assignment"
      organization_teammate_assignment_path(organization, teammate, entity_id)
    when "Aspiration"
      organization_teammate_aspiration_path(organization, teammate, entity_id)
    end
  end

  private

  def teammate_and_manager_short_names(teammate, organization)
    employee_person = teammate.person
    company = organization.root_company || organization
    manager_person = Goals::HealthManagerPerson.for(teammate, company: company)

    employee = check_ins_health_popover_person_name(employee_person, fallback: "Employee")
    manager = check_ins_health_popover_person_name(manager_person, fallback: "Manager")

    if employee == manager
      employee = check_ins_health_disambiguated_person_name(employee_person, employee, "Employee")
      manager = check_ins_health_disambiguated_person_name(manager_person, manager, "Manager")
    end

    if employee == manager
      employee = "#{employee} (employee)"
      manager = "#{manager} (manager)"
    end

    { employee: employee, manager: manager }
  end

  def check_ins_health_popover_person_name(person, fallback:)
    return fallback if person.blank?

    person.casual_name.presence || person.first_name.presence || fallback
  end

  def check_ins_health_disambiguated_person_name(person, current_name, fallback)
    return current_name if person.blank?

    given = person.preferred_name.presence || person.first_name.presence || current_name
    return fallback if given.blank?

    if person.last_name.present?
      "#{given} #{person.last_name[0]}."
    else
      given
    end
  end

  def show_workflow_steps_popover?(item)
    return true if item.status.in?([EngagementHealth::AT_RISK, EngagementHealth::NEEDS_ATTENTION])

    inputs = item.inputs
    inputs["open_check_in_present"] && (inputs["open_employee_completed"] || inputs["open_manager_completed"])
  end

  def healthy_popover_body(item:)
    days = check_ins_health_resolved_days_until_at_risk(item)
    message = if days.nil?
                "Consider a check-in when ready"
              elsif days.zero?
                "Consider a check-in now"
              else
                "Consider a check-in in #{days} #{'day'.pluralize(days)}"
              end
    %(<hr class="my-1"><div>#{ERB::Util.html_escape(message)}</div>)
  end

  def check_ins_health_inferred_action_bar_color(item)
    inputs = item.inputs
    open_present = inputs["open_check_in_present"]

    if open_present
      employee_done = inputs["open_employee_completed"]
      manager_done = inputs["open_manager_completed"]
      return "light_green" if employee_done && manager_done
      return "light_blue" if employee_done && !manager_done
      return "light_purple" if manager_done && !employee_done
    end

    case item.status
    when EngagementHealth::NEEDS_ATTENTION
      open_present ? "red" : "red"
    when EngagementHealth::AT_RISK
      "orange"
    when EngagementHealth::HEALTHY
      if inputs["previous_finalized_acknowledged"] == true
        "neon_green_striped"
      elsif inputs["previous_finalized_awaiting_acknowledgment"] == true
        "green_striped"
      else
        "neon_green_striped"
      end
    else
      "anomaly_gray"
    end
  end

  def check_ins_health_resolved_days_since_last_event(item)
    days_since = item.inputs["days_since_last_event"]
    return days_since unless days_since.nil?

    last_event_at = item.inputs["last_event_at"]
    return nil if last_event_at.blank?

    EngagementHealth::Thresholds.days_since(Time.zone.parse(last_event_at.to_s), reference_time: Time.current)
  rescue ArgumentError, TypeError
    nil
  end

  def workflow_steps_popover_body(item:, employee_name:, manager_name:)
    inputs = item.inputs
    employee_done = inputs["open_employee_completed"]
    manager_done = inputs["open_manager_completed"]

    consider = if item.status.in?([EngagementHealth::AT_RISK, EngagementHealth::NEEDS_ATTENTION]) && !inputs["open_check_in_present"]
                 "<div class=\"mt-1\">Consider a check-in now</div>"
               else
                 ""
               end

    <<~HTML
      <hr class="my-1">
      <div class="check-ins-health-workflow-steps">
        <div>#{workflow_step_line(1, "#{ERB::Util.html_escape(employee_name)} does a self-assessment alone", employee_done)}</div>
        <div>#{workflow_step_line(2, "#{ERB::Util.html_escape(manager_name)} does a self-assessment alone", manager_done)}</div>
        <div>#{workflow_step_line(3, "Both review together and finalize", false)}</div>
      </div>
      #{consider}
    HTML
  end

  def workflow_step_line(number, label, complete)
    icon = if complete
             '<i class="bi bi-check-circle-fill text-success ms-1" aria-hidden="true"></i>'
           else
             '<i class="bi bi-circle text-muted ms-1" aria-hidden="true"></i>'
           end
    "(#{number}) #{label} #{icon}"
  end

  def format_check_ins_health_last_finalized(iso8601_value)
    return "Never" if iso8601_value.blank?

    time = Time.zone.parse(iso8601_value.to_s)
    return "Never" unless time

    time.strftime("%b %-d, %Y")
  rescue ArgumentError, TypeError
    "Never"
  end
end
