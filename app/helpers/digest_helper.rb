# frozen_string_literal: true

module DigestHelper
  WEEKLY_DIGEST_DAY_LABELS = {
    '0' => 'Sunday',
    '1' => 'Monday',
    '2' => 'Tuesday',
    '3' => 'Wednesday',
    '4' => 'Thursday',
    '5' => 'Friday',
    '6' => 'Saturday',
    'off' => 'no weekly reminder'
  }.freeze

  ONE_ON_ONE_DIGEST_POPOVER = <<~HTML.squish
    <strong>The one thing</strong> — opinionated focus for your 1:1 each week. Surfaces the priority order of what matters most for you and your manager to discuss, week over week.<br><br>
    About Me and 1:1 try to serve a similar purpose. Pick whichever style fits you best.
  HTML

  ABOUT_ME_DIGEST_POPOVER = <<~HTML.squish
    <strong>Choose your own adventure</strong> — a less opinionated weekly pulse. Summarizes how healthy eight general areas of clarity are (green, yellow, red), without telling you what to discuss first.<br><br>
    About Me and 1:1 try to serve a similar purpose. Pick whichever style fits you best.
  HTML

  def weekly_digest_day_label(day_value)
    WEEKLY_DIGEST_DAY_LABELS[day_value.to_s] || 'no weekly reminder'
  end

  def weekly_digest_names_for_prefs(one_on_one_on:, about_me_on:)
    names = []
    names << '1:1 guide' if one_on_one_on
    names << 'About Me reminder' if about_me_on
    names
  end

  def weekly_digest_summary_sentence(one_on_one_on:, about_me_on:, weekly_day:)
    day_label = weekly_digest_day_label(weekly_day)
    digest_names = weekly_digest_names_for_prefs(one_on_one_on: one_on_one_on, about_me_on: about_me_on)

    if digest_names.empty? || weekly_day.to_s == 'off'
      'No weekly Slack reminders scheduled'
    elsif digest_names.size == 1
      "Will send #{digest_names.first} on #{day_label}"
    else
      "Will send #{digest_names.first} and #{digest_names.last} on #{day_label}"
    end
  end

  def weekly_reminder_configured?(one_on_one_on:, about_me_on:, weekly_day:)
    weekly_day.to_s != 'off' && weekly_day.present? && (one_on_one_on || about_me_on)
  end

  def weekly_digest_enabled_in_prefs?(prefs, key)
    return prefs.preferences[key.to_s] == 'on' if prefs.preferences.key?(key.to_s)

    true
  end

  def digest_popover_data_attributes(content_html)
    {
      bs_toggle: 'popover',
      bs_trigger: 'hover focus',
      bs_placement: 'top',
      bs_html: true,
      bs_content: content_html
    }
  end

  def one_on_one_digest_popover_content
    ONE_ON_ONE_DIGEST_POPOVER
  end

  def about_me_digest_popover_content
    ABOUT_ME_DIGEST_POPOVER
  end
end
