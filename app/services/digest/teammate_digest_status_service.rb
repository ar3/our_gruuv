# frozen_string_literal: true

module Digest
  # Explains why scheduled digests may not send and summarizes recent digest notifications.
  class TeammateDigestStatusService
    ROOT_DIGEST_TYPES = %w[gsd_digest about_me_digest one_on_one_digest].freeze

    DigestEvent = Struct.new(:digest_key, :label, :sent_at, :status, :medium, keyword_init: true)

    def initialize(teammate:, organization:, gsd_label: 'Get Shit Done', gsd_pending_count: nil, recent_notifications: nil)
      @teammate = teammate
      @organization = organization
      @person = teammate.person
      @prefs = UserPreference.for_person(@person)
      @gsd_label = gsd_label
      @gsd_pending_count = gsd_pending_count
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
      if @person.timezone.blank?
        blockers << 'Add a timezone in the profile so weekday 8:00 AM sends can be scheduled.'
      end
      unless gsd_medium_enabled?
        blockers << 'Turn on Slack or SMS in delivery mediums.'
      end
      if slack_medium_on? && !employee_slack_deliverable?
        blockers << 'Connect Slack for this teammate (Slack Settings) to receive Slack digests.'
      end
      if slack_medium_on? && employee_slack_deliverable? && !organization_slack_configured?
        blockers << 'Organization Slack is not configured — Slack digests cannot be delivered.'
      end
      if sms_medium_on? && @person.unique_textable_phone_number.blank?
        blockers << 'Add a phone number in the profile to receive SMS digests.'
      end
      if @gsd_pending_count&.zero?
        blockers << "No items in #{@gsd_label} — the digest only sends when there is at least one pending item."
      end
      blockers
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
      else notification_type
      end
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
      unless weekly_slack_scheduling_enabled?
        blockers << 'Turn on Slack digest for this employee or their manager (delivery mediums / profile).'
      end
      if weekly_slack_scheduling_enabled? && weekly_slack_user_ids.empty?
        blockers << 'Connect Slack for the employee and/or manager so a group DM can be opened.'
      end
      if weekly_slack_scheduling_enabled? && weekly_slack_user_ids.any? && !organization_slack_configured?
        blockers << 'Organization Slack is not configured — weekly Slack digests cannot be delivered.'
      end
      blockers
    end

    def weekly_slack_scheduling_enabled?
      employee_slack_medium_on? || manager_slack_medium_on?
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

    def gsd_medium_enabled?
      slack_medium_on? || sms_medium_on? || @prefs.effective_digest_email == 'on'
    end

    def slack_medium_on?
      @prefs.effective_digest_slack(nil) == 'on'
    end

    def sms_medium_on?
      @prefs.effective_digest_sms(nil) == 'on'
    end

    def employee_slack_medium_on?
      slack_medium_on?
    end

    def manager_slack_medium_on?
      @manager_prefs&.effective_digest_slack(nil) == 'on'
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
