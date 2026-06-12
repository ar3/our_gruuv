# frozen_string_literal: true

module Digest
  class ScheduleAboutMeJob < ApplicationJob
    queue_as :default

    DIGEST_HOUR = 8

    def perform
      now_utc = Time.current
      enqueued_about_me = 0
      enqueued_one_on_one = 0

      CompanyTeammate.employed.includes(:person).find_each do |teammate|
        person = teammate.person
        next if person.timezone.blank?

        prefs = UserPreference.for_person(person)
        weekly_day = prefs.preference(:about_me_weekly_day).to_s
        next if weekly_day == 'off' || weekly_day.blank?
        next unless weekly_day.match?(/\A[0-6]\z/)

        local_time = now_utc.in_time_zone(person.timezone)
        next unless local_time.hour == DIGEST_HOUR
        next unless local_time.wday == weekly_day.to_i

        week_key = local_time.strftime('%G-%V')

        if prefs.preference(:about_me_last_sent_week).to_s != week_key &&
           prefs.weekly_digest_enabled?(:about_me_digest_enabled)
          Digest::SendAboutMeJob.perform_later(teammate.id, week_key)
          enqueued_about_me += 1
        end

        if prefs.preference(:one_on_one_last_sent_week).to_s != week_key &&
           prefs.weekly_digest_enabled?(:one_on_one_digest_enabled)
          Digest::SendOneOnOneDigestJob.perform_later(teammate.id, week_key)
          enqueued_one_on_one += 1
        end
      end

      Rails.logger.info(
        "Digest::ScheduleAboutMeJob: at #{now_utc.iso8601} enqueued " \
        "#{enqueued_one_on_one} one_on_one and #{enqueued_about_me} about_me digests"
      )
    end
  end
end
