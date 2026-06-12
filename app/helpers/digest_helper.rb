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

  # Human-readable list of notification types turned on (for nudge summaries).
  def notification_nudge_enabled_items(prefs:, gsd_label: 'Get Shit Done')
    items = []
    items << gsd_label if prefs.gsd_digest_enabled?
    items << 'Interesting Things' if prefs.interesting_things_digest_enabled?

    weekly_day = prefs.preference(:about_me_weekly_day).presence || 'off'
    one_on_one_on = prefs.preference(:one_on_one_digest_enabled) == 'on'
    about_me_on = prefs.preference(:about_me_digest_enabled) == 'on'
    if weekly_reminder_configured?(one_on_one_on:, about_me_on:, weekly_day:)
      items << weekly_digest_nudge_phrase(one_on_one_on:, about_me_on:, weekly_day:)
    end
    items
  end

  def notification_nudge_disabled_items(prefs:, gsd_label: 'Get Shit Done')
    weekly_day = prefs.preference(:about_me_weekly_day).presence || 'off'
    one_on_one_on = prefs.preference(:one_on_one_digest_enabled) == 'on'
    about_me_on = prefs.preference(:about_me_digest_enabled) == 'on'

    items = []
    items << "daily #{gsd_label} reminders" unless prefs.gsd_digest_enabled?
    items << 'Interesting Things updates' unless prefs.interesting_things_digest_enabled?
    items << 'weekly recap digests' unless weekly_reminder_configured?(one_on_one_on:, about_me_on:, weekly_day:)
    items
  end

  def notification_nudge_partial_sentence(casual_name:, prefs:, gsd_label: 'Get Shit Done')
    disabled = notification_nudge_disabled_items(prefs: prefs, gsd_label: gsd_label)
    return nil if disabled.empty?

    list = disabled.to_sentence(two_words_connector: ' and ', last_word_connector: ', and ')
    "Still off for #{casual_name}: #{list}."
  end

  def notification_nudge_summary_sentence(casual_name:, prefs:, gsd_label: 'Get Shit Done')
    items = notification_nudge_enabled_items(prefs: prefs, gsd_label: gsd_label)
    return nil if items.empty?

    list = items.to_sentence(two_words_connector: ' and ', last_word_connector: ', and ')
    "#{casual_name} has notifications configured for #{list}."
  end

  def weekly_digest_nudge_phrase(one_on_one_on:, about_me_on:, weekly_day:)
    day = weekly_digest_day_label(weekly_day)
    digest_names = weekly_digest_names_for_prefs(one_on_one_on: one_on_one_on, about_me_on: about_me_on)
    if digest_names.size == 1
      "weekly #{digest_names.first.downcase} on #{day}s"
    else
      "weekly #{digest_names.first.downcase} and #{digest_names.last.downcase} on #{day}s"
    end
  end

  def weekly_digest_enabled_in_prefs?(prefs, key)
    prefs.weekly_digest_enabled?(key)
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

  def digest_week_key_label(week_key)
    year, week = week_key.to_s.split('-').map(&:to_i)
    return "Week #{week_key}" if year.zero? || week.zero?

    start = Date.commercial(year, week, 1)
    "Week of #{start.strftime('%b %-d, %Y')}"
  rescue ArgumentError
    "Week #{week_key}"
  end

  def digest_event_status_label(status)
    case status.to_s
    when 'sent_successfully' then 'Sent'
    when 'send_failed' then 'Failed'
    when 'preparing_to_send' then 'Queued'
    else 'Unknown'
    end
  end
end
