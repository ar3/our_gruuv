# frozen_string_literal: true

module Digest
  # Runs every hour; finds teammates for whom it is 8:00 AM in their timezone and
  # enqueues SendDigestJob for daily or weekly digest (weekly only on their digest_weekly_day, default Monday).
  class ScheduleDigestsJob < ApplicationJob
    queue_as :default

    DIGEST_HOUR = 8
    DEFAULT_WEEKLY_DAY = 1 # Monday (0=Sunday, 1=Monday, ... 6=Saturday)

    def perform
      now_utc = Time.current

      CompanyTeammate.employed.includes(:person).find_each do |teammate|
        next unless teammate.organization

        person = teammate.person
        tz = person.timezone.presence
        next if tz.blank?

        prefs = UserPreference.for_person(person)
        freq = digest_frequency(prefs, teammate)
        next unless freq.in?(%w[daily weekly])

        local_time = now_utc.in_time_zone(tz)
        next unless local_time.hour == DIGEST_HOUR

        if freq == 'weekly'
          weekly_day = (prefs.preference('digest_weekly_day').presence || DEFAULT_WEEKLY_DAY).to_i
          next unless local_time.wday == weekly_day
        end

        SendDigestJob.perform_later(teammate.id)
      end
    end

    private

    def digest_frequency(prefs, teammate)
      slack_freq = prefs.effective_digest_slack(teammate)
      email_freq = prefs.effective_digest_email
      sms_freq = prefs.effective_digest_sms(teammate.person)
      [slack_freq, email_freq, sms_freq].find { |f| f.in?(%w[daily weekly]) }
    end
  end
end
