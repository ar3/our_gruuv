# frozen_string_literal: true

module HealthNudgesHelper
  def health_nudge_casual_name(teammate)
    person = teammate&.person
    person&.casual_name.presence || person&.first_name.presence || person&.display_name.presence || "them"
  end

  def health_nudge_manager_only_button_label(manager)
    "Send to me and #{health_nudge_casual_name(manager)}"
  end

  def health_nudge_manager_and_skip_button_label(manager, skip_level)
    "Send to me, #{health_nudge_casual_name(manager)}, and #{health_nudge_casual_name(skip_level)}"
  end

  def health_nudge_can_send?(recipients)
    return false if recipients.blank?
    return false if recipients.any? { |tm| tm.slack_user_id.blank? }

    recipients.map(&:slack_user_id).uniq.length >= 2
  end

  def health_nudge_send_disabled_reason(recipients, viewer:, skip_required: false, skip_level: nil)
    return "You must be a teammate in this organization." if viewer.blank?
    return "This manager has no manager on file." if skip_required && skip_level.nil?

    missing = recipients.select { |tm| tm.slack_user_id.blank? }
    if missing.any?
      names = missing.map { |tm| tm.id == viewer.id ? "you" : (tm.person&.display_name || "a recipient") }
      return "Slack required for #{names.to_sentence}."
    end

    return "Need at least two distinct Slack accounts." if recipients.map(&:slack_user_id).uniq.length < 2

    nil
  end

  def health_nudge_panel_locals(manager_id:)
    config = @health_nudge_config
    {
      label: config[:label],
      collapse_id: "healthNudge-#{@health_nudge_object}",
      nudge_path: public_send(config[:nudge_path_name], @organization),
      manager: @health_nudge_manager,
      skip_level: @health_nudge_skip_level,
      recipients_manager: @health_nudge_recipients_manager,
      recipients_manager_and_skip: @health_nudge_recipients_manager_and_skip,
      message: @health_nudge_message,
      last_nudge: @last_health_nudge,
      manager_id: manager_id
    }
  end

  def health_nudge_toolbar_captures(manager_id:)
    return { aside_html: nil, below_html: nil } unless @health_nudge_manager.present?

    locals = health_nudge_panel_locals(manager_id: manager_id)
    {
      aside_html: capture { render "organizations/health/nudge_trigger", **locals },
      below_html: capture { render "organizations/health/nudge_expand", **locals }
    }
  end
end
