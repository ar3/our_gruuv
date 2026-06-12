# frozen_string_literal: true

module Digest
  # Explains why scheduled digests may not send and summarizes recent digest notifications.
  class TeammateDigestStatusService
    ROOT_DIGEST_TYPES = %w[gsd_digest about_me_digest one_on_one_digest interesting_things_digest].freeze

    DigestEvent = Struct.new(:digest_key, :label, :sent_at, :status, :medium, keyword_init: true)

    def initialize(teammate:, organization:, gsd_label: 'Get Shit Done', gsd_pending_count: nil,
                   interesting_pending_count: nil, recent_notifications: nil)
      @teammate = teammate
      @organization = organization
      @person = teammate.person
      @prefs = UserPreference.for_person(@person)
      @gsd_label = gsd_label
      @gsd_pending_count = gsd_pending_count
      @interesting_pending_count = interesting_pending_count
      @recent_notifications = recent_notifications
      @manager_teammate = teammate.active_employment_tenure&.manager_teammate
      @manager_prefs = @manager_teammate ? UserPreference.for_person(@manager_teammate.person) : nil
    end

    def recent_events(weeks: 3)
      cutoff = weeks.weeks.ago
      root_notifications.select { |n| n.created_at >= cutoff }.map { |n| build_event(n) }
    end

    def recent_events_by_week(weeks: 3)
      recent_events(weeks: weeks).group_by { |event| event.sent_at.in_time_zone(person_timezone).strftime('%G-W%V') }
    end

    def gsd_blockers
      blockers = []
      blockers << 'This notification is turned off.' unless @prefs.gsd_digest_enabled?
      blockers.concat(daily_delivery_blockers)
      if @gsd_pending_count&.zero?
        blockers << "No items in #{@gsd_label} — this only sends when there is at least one pending item."
      end
      blockers
    end

    def interesting_things_blockers
      blockers = []
      blockers << 'This notification is turned off.' unless @prefs.interesting_things_digest_enabled?
      blockers.concat(daily_delivery_blockers)
      blockers
    end

    # Weekly delivery blockers independent of which style (1:1 / About Me) is selected.
    def weekly_blockers
      weekly_schedule_blockers + weekly_slack_delivery_blockers
    end

    def one_on_one_blockers
      weekly_schedule_blockers + weekly_slack_delivery_blockers +
        toggle_blocker(:one_on_one_digest_enabled, 'Weekly 1:1 guide digest is turned off.')
    end

    def about_me_blockers
      weekly_schedule_blockers + weekly_slack_delivery_blockers +
        toggle_blocker(:about_me_digest_enabled, 'Weekly About Me reminder digest is turned off.')
    end

    def gsd_schedule_summary
      tz_label = @person.timezone.presence || 'timezone not set'
      "Weekdays at 8:00 AM (#{tz_label}) when #{@gsd_label} has pending items."
    end

    def interesting_things_schedule_summary
      tz_label = @person.timezone.presence || 'timezone not set'
      "Weekdays at 8:00 AM (#{tz_label}) when there are new things on the Interesting Things page since the last visit."
    end

    def weekly_schedule_summary
      day = @prefs.preference(:about_me_weekly_day).to_s
      return 'No weekly reminder day selected.' if day == 'off' || day.blank?

      day_name = DigestHelper::WEEKLY_DIGEST_DAY_LABELS[day] || day
      tz_label = @person.timezone.presence || 'timezone not set'
      "#{day_name}s at 8:00 AM (#{tz_label}) via Slack group DM with employee and manager."
    end

    def already_sent_this_week?(digest_key)
      week_key = current_iso_week_key
      case digest_key
      when :one_on_one
        @prefs.preference(:one_on_one_last_sent_week).to_s == week_key
      when :about_me
        @prefs.preference(:about_me_last_sent_week).to_s == week_key
      else
        false
      end
    end

    # Reasons ScheduleAboutMeJob would skip this teammate right now (or at 8am today).
    def schedule_diagnosis(at: Time.current)
      lines = []
      unless @teammate.employed?
        lines << 'Teammate is not employed (scheduler only iterates CompanyTeammate.employed).'
      end
      if @person.timezone.blank?
        lines << 'Person timezone is blank — scheduler skips (does not use Eastern default).'
      end

      weekly_day = @prefs.preference(:about_me_weekly_day).to_s
      if weekly_day == 'off' || weekly_day.blank?
        lines << 'Weekly reminder day is off.'
      elsif !weekly_day.match?(/\A[0-6]\z/)
        lines << "Weekly reminder day #{weekly_day.inspect} is invalid."
      end

      local = at.in_time_zone(person_timezone)
      if local.hour != Digest::ScheduleAboutMeJob::DIGEST_HOUR
        lines << "Scheduler only enqueues during the 8:00 local hour (now #{local.strftime('%-I:%M %p %Z')})."
      end

      if weekly_day.match?(/\A[0-6]\z/) && local.wday != weekly_day.to_i
        today = DigestHelper::WEEKLY_DIGEST_DAY_LABELS[local.wday.to_s]
        scheduled = DigestHelper::WEEKLY_DIGEST_DAY_LABELS[weekly_day]
        lines << "Today is #{today}; digest is scheduled for #{scheduled}."
      end

      week_key = local.strftime('%G-%V')
      if @prefs.preference(:one_on_one_last_sent_week).to_s == week_key
        lines << "one_on_one_last_sent_week is #{week_key} — scheduler will not re-enqueue 1:1 this week."
      end
      unless @prefs.weekly_digest_enabled?(:one_on_one_digest_enabled)
        lines << 'one_on_one_digest_enabled is off for this employee (not the manager viewing digest settings).'
      end

      lines
    end

    def next_weekly_send_label(digest_key)
      weekly_day = @prefs.preference(:about_me_weekly_day).to_s
      return 'Not scheduled — no weekly day selected.' unless weekly_day.match?(/\A[0-6]\z/)

      day_name = DigestHelper::WEEKLY_DIGEST_DAY_LABELS[weekly_day]
      tz = @person.timezone.presence || 'UTC'
      toggle_ok =
        case digest_key
        when :one_on_one then @prefs.weekly_digest_enabled?(:one_on_one_digest_enabled)
        when :about_me then @prefs.weekly_digest_enabled?(:about_me_digest_enabled)
        else true
        end
      return "Not scheduled — #{digest_key} digest toggle is off for this employee." unless toggle_ok

      local = Time.current.in_time_zone(tz)
      days_ahead = (weekly_day.to_i - local.wday) % 7
      days_ahead = 7 if days_ahead.zero? && local.hour >= Digest::ScheduleAboutMeJob::DIGEST_HOUR
      next_date = local.to_date + days_ahead
      "Next window: #{day_name}, #{next_date.strftime('%b %-d, %Y')} at 8:00 AM #{tz}"
    end

    private

    def root_notifications
      @root_notifications ||= begin
        if @recent_notifications
          @recent_notifications.select { |n| n.main_thread_id.nil? && ROOT_DIGEST_TYPES.include?(n.notification_type) }
        else
          Notification.where(
            notifiable: @teammate,
            notification_type: ROOT_DIGEST_TYPES,
            main_thread_id: nil
          ).order(created_at: :desc).limit(50).to_a
        end
      end
    end

    def build_event(notification)
      DigestEvent.new(
        digest_key: notification.notification_type,
        label: digest_label_for(notification.notification_type),
        sent_at: notification.created_at,
        status: notification.status,
        medium: 'Slack'
      )
    end

    def digest_label_for(notification_type)
      case notification_type
      when 'gsd_digest' then @gsd_label
      when 'one_on_one_digest' then '1:1 guide'
      when 'about_me_digest' then 'About Me reminder'
      when 'interesting_things_digest' then 'Interesting Things'
      else notification_type
      end
    end

    # Slack is the always-on channel: deliverability depends on a connected identity, not a preference.
    def daily_delivery_blockers
      blockers = []
      if @person.timezone.blank?
        blockers << 'Add a timezone in the profile so weekday 8:00 AM sends can be scheduled.'
      end
      unless employee_slack_deliverable?
        blockers << 'Connect Slack for this teammate (Slack Settings) to receive Slack notifications.'
      end
      if employee_slack_deliverable? && !organization_slack_configured?
        blockers << 'Organization Slack is not configured — Slack notifications cannot be delivered.'
      end
      if sms_medium_on? && @person.unique_textable_phone_number.blank?
        blockers << 'Add a phone number in the profile to receive SMS notifications.'
      end
      blockers
    end

    def weekly_schedule_blockers
      blockers = []
      if @person.timezone.blank?
        blockers << 'Add a timezone in the employee profile so 8:00 AM sends can be scheduled.'
      end
      weekly_day = @prefs.preference(:about_me_weekly_day).to_s
      if weekly_day == 'off' || weekly_day.blank? || !weekly_day.match?(/\A[0-6]\z/)
        blockers << 'Select a weekly reminder day (not "No weekly reminder").'
      end
      blockers
    end

    def weekly_slack_delivery_blockers
      blockers = []
      if weekly_slack_user_ids.empty?
        blockers << 'Connect Slack for the employee and/or manager so a group DM can be opened.'
      end
      if weekly_slack_user_ids.any? && !organization_slack_configured?
        blockers << 'Organization Slack is not configured — weekly Slack digests cannot be delivered.'
      end
      blockers
    end

    def weekly_slack_user_ids
      ids = []
      ids << @teammate.slack_user_id if employee_slack_deliverable?
      if @manager_teammate&.has_slack_identity? && @manager_teammate.slack_user_id.present?
        ids << @manager_teammate.slack_user_id
      end
      ids.uniq
    end

    def toggle_blocker(pref_key, message)
      @prefs.weekly_digest_enabled?(pref_key) ? [] : [message]
    end

    def sms_medium_on?
      @prefs.effective_digest_sms(nil) == 'on'
    end

    def employee_slack_deliverable?
      @teammate.has_slack_identity? && @teammate.slack_user_id.present?
    end

    def organization_slack_configured?
      @organization.calculated_slack_config&.configured?
    end

    def person_timezone
      @person.timezone.presence || 'UTC'
    end

    def current_iso_week_key
      Time.current.in_time_zone(person_timezone).strftime('%G-%V')
    end
  end
end
