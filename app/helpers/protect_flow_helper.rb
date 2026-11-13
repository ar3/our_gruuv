# frozen_string_literal: true

module ProtectFlowHelper
  def protect_flow_status_badge_class(status)
    case status
    when EngagementHealth::HEALTHY
      "text-bg-success"
    when EngagementHealth::WARNING
      "text-bg-warning"
    when EngagementHealth::NEEDS_ATTENTION
      "text-bg-danger"
    else
      "text-bg-secondary"
    end
  end

  def protect_flow_status_label(status)
    return "Pending" if status.blank?

    EngagementHealth::STATUS_LABELS.fetch(status, status.to_s.humanize)
  end

  def protect_flow_week_label(week_start)
    Date.parse(week_start.to_s).strftime("%b %-d, %Y")
  rescue ArgumentError, TypeError
    week_start.to_s
  end

  # Short day label for snapshot captions, e.g. "Nov 9th".
  def protect_flow_day_label(value)
    date =
      case value
      when Date then value
      when Time, ActiveSupport::TimeWithZone then value.in_time_zone.to_date
      else
        Time.zone.parse(value.to_s)&.to_date || Date.parse(value.to_s)
      end
    "#{date.strftime('%b')} #{date.day.ordinalize}"
  rescue ArgumentError, TypeError
    value.to_s
  end

  def protect_flow_person_week_summary(person)
    current_needs_work = person[:current_needs_work_count]
    current_needs_work =
      if current_needs_work.nil?
        Array(person[:attention_items]).count { |a| a[:category].to_s != "pending_health" }
      else
        current_needs_work.to_i
      end

    # Prefer the week pool (start vs current); never treat open Needs Attention/Warning as "on track".
    needs_work = person[:week_needs_work_count]
    needs_work =
      if needs_work.nil?
        [person[:start_needs_work_count].to_i, current_needs_work].max
      else
        needs_work.to_i
      end
    needs_work = current_needs_work if needs_work.zero? && current_needs_work.positive?

    improved = person[:improved_count].to_i
    keep_or_get = current_needs_work.zero? ? "keep" : "get"

    text =
      if needs_work.zero? && current_needs_work.zero?
        "So far this week, we're on track — and in less than 15 minutes a week, we can #{keep_or_get} all of these essential clarity signals steady 💪🏾"
      else
        signal_word = "signal".pluralize(needs_work)
        "So far this week, of the #{needs_work} warning/unhealthy #{signal_word}, we've improved #{improved} so far… and in less than 15 minutes a week, we can #{keep_or_get} all of these essential clarity signals steady 💪🏾"
      end
    text.html_safe
  end

  # Renders an opportunity sentence hash with an inline action link (no bullet lists).
  def protect_flow_opportunity_sentence(opportunity)
    return if opportunity.blank?
    return content_tag(:span, opportunity.to_s) unless opportunity.is_a?(Hash)

    before = opportunity[:before].to_s
    link_text = opportunity[:link_text]
    link_path = opportunity[:link_path]
    after = opportunity[:after].to_s
    method = opportunity[:link_method]

    parts = []
    parts << before if before.present?
    if link_text.present? && link_path.present?
      link_opts = { class: "link-primary" }
      link_opts[:data] = { turbo_method: method } if method.present?
      parts << link_to(link_text, link_path, link_opts)
    elsif link_text.present?
      parts << link_text
    end
    parts << after if after.present?
    safe_join(parts)
  end
end
